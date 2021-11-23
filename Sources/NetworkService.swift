//
//  NetworkService.swift
//  NetworkingX
//
//  Created by Prashant Shrestha on 5/24/20.
//  Copyright © 2020 Prashant Shrestha. All rights reserved.
//

import Foundation

/**
 An enum representation for common network calls errors.
 
 Please use this for commonality instead of other Error objects, in case of network calls.
 */
public enum NetworkError: Error {
    case cancelled
    case error(statusCode: Int, data: Data?)
    case generic(Error)
    case genericMessage(String)
    case notConnected
    case timedOut
    case unacceptableStatusCode(code: Int)
    case urlGeneration
}

/**
 A protocol wrapper for network call with essential functions.
 */
public protocol NetworkCallable {
    func cancel()
    func resume()
    func suspend()
    var progress: Progress { get }
}

extension URLSessionTask: NetworkCallable { }


/**
 A service protocols used to make network requests
 */
public protocol NetworkService {
    typealias CompletionHandler = (Result<Data?, NetworkError>) -> Void
    
    
    /// Makes network requests
    /// - Parameters:
    ///   - endpoint: User defined Endpoint requestable object.
    ///   - completion: escaping handler for network result.
    /// - returns: a NetworkCallable object which is basically URLSessionTask. Typically, you can use it to resume, cancel, suspend the network requests.
    func request(endpoint: Requestable, completion: @escaping CompletionHandler) -> NetworkCallable?
}

/**
 A protocol used to manage network request sessions.
 
 NetworkSessionManager works as an interceptor in between any network calls. Typically, you can see it being used in NetworkService implementation classes.
 
 # Usage:
 - Basically to add access tokens or credentials before requesting calls.
 - resolve errors.
 - configure acceptable status codes
 */
public protocol NetworkSessionManager {
    /**
     Configure acceptable HTTP codes.
     
     default acceptable status codes are:
     ```
     200..<300
     ```
     */
    var acceptableStatusCodes: [Int] { get }
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    
    func request(_ request: URLRequest,
                 completion: @escaping CompletionHandler) -> NetworkCallable
}

public extension NetworkSessionManager {
    var acceptableStatusCodes: [Int] { return Array(200..<300) }
}

/**
 A protocol used to log any errors occured in network requests.
 
 # Usage:
 You can find it's usage in NetworkService implementation classes.
 */
public protocol NetworkErrorLogger {
    
    /// A function to log network requests and their configurations.
    /// - Parameter request: URLRequest object for network call.
    func log(request: URLRequest)
    
    /// A logger to log network responses of respective requests.
    /// - Parameters:
    ///   - data: typically, an .utf8 encoded Data object
    ///   - response: URLResponse object.
    func log(responseData data: Data?, response: URLResponse?)
    
    /// A logger to log any errors occured in network requests
    /// - Parameter error: Error object. It's usually a NetworkError object prior to it's usage in NetworkService implementation class.
    func log(error: Error)
}

// MARK: - Implementation

/// A default implementation class for NetworkService protocol.
public final class DefaultNetworkService {
    
    private let config: NetworkConfigurable
    private let sessionManager: NetworkSessionManager
    private let logger: NetworkErrorLogger
    
    /// Initializer
    /// - Parameters:
    ///   - config: Network config object. Typically, a ApiDataNetworkConfig object.
    ///   - sessionManager: injecting a NetworkSessionManager object.
    ///   - logger: Network Logger implemented from protocol NetworkErrorLogger
    public init(config: NetworkConfigurable,
                sessionManager: NetworkSessionManager = DefaultNetworkSessionManager(),
                logger: NetworkErrorLogger = DefaultNetworkErrorLogger()) {
        self.sessionManager = sessionManager
        self.config = config
        self.logger = logger
    }
    
    
    /// A private function which calls for network requests. It handles the HTTP status codes and resolves HTTP Error to NetworkError.
    /// - Parameters:
    ///   - request: URLRequest object.
    ///   - completion: escaping handler for network result.
    /// - Returns: a NetworkCallable object. Typically, you can use it to resume, cancel, suspend the network requests.
    private func request(request: URLRequest, completion: @escaping CompletionHandler) -> NetworkCallable {
        
        let sessionDataTask = sessionManager.request(request) { [self] data, response, requestError in
            if let response = response as? HTTPURLResponse {
                if self.sessionManager.acceptableStatusCodes.contains(response.statusCode) {
                    self.logger.log(responseData: data, response: response)
                    completion(.success(data))
                } else {
                    var error: NetworkError
                    if let data = data {
                        error = .error(statusCode: response.statusCode, data: data)
                    } else if let requestError = requestError {
                        error = self.resolve(error: requestError)
                    } else {
                        error = .unacceptableStatusCode(code: response.statusCode)
                    }
                    
                    self.logger.log(error: error)
                    completion(.failure(error))
                }
            } else {
                if let requestError = requestError {
                    var error: NetworkError
                    if let response = response as? HTTPURLResponse {
                        error = .error(statusCode: response.statusCode, data: data)
                    } else {
                        error = self.resolve(error: requestError)
                    }
                    
                    self.logger.log(error: error)
                    completion(.failure(error))
                } else {
                    self.logger.log(responseData: data, response: response)
                    completion(.success(data))
                }
            }
        }
    
        logger.log(request: request)

        return sessionDataTask
    }
    
    /// Resolves generic Error types to NetworkError types.
    /// - Parameter error: a generic object of type Error.
    /// - Returns: a enum object of NetworkError.
    private func resolve(error: Error) -> NetworkError {
        let code = URLError.Code(rawValue: (error as NSError).code)
        switch code {
        case .notConnectedToInternet: return .notConnected
        case .cancelled: return .cancelled
        case .timedOut: return .timedOut
        default: return .generic(error)
        }
    }
}

extension DefaultNetworkService: NetworkService {
    
    public func request(endpoint: Requestable, completion: @escaping CompletionHandler) -> NetworkCallable? {
        do {
            let urlRequest = try endpoint.urlRequest(with: config)
            return request(request: urlRequest, completion: completion)
        } catch {
            completion(.failure(.urlGeneration))
            return nil
        }
    }
}

// MARK: - Default Network Session Manager

/// - Note: If authorization is needed NetworkSessionManager can be implemented by using,
/// for example, Alamofire SessionManager with its RequestAdapter and RequestRetrier.
/// And it can be incjected into NetworkService instead of default one.
public class DefaultNetworkSessionManager: NetworkSessionManager {
    public init() {}
    public func request(_ request: URLRequest,
                        completion: @escaping CompletionHandler) -> NetworkCallable {
        let task = URLSession.shared.dataTask(with: request, completionHandler: completion)
        task.resume()
        return task
    }
}

// MARK: - Logger
/// Default implementation of NetworkErrorLogger
public final class DefaultNetworkErrorLogger: NetworkErrorLogger {
    public init() { }

    public func log(request: URLRequest) {
        print("-------------")
        print("request: \(request.url!)")
        print("headers: \(request.allHTTPHeaderFields!)")
        print("method: \(request.httpMethod!)")
        if let httpBody = request.httpBody, let result = ((try? JSONSerialization.jsonObject(with: httpBody, options: []) as? [String: AnyObject]) as [String: AnyObject]??) {
            printIfDebug("body: \(String(describing: result))")
        } else if let httpBody = request.httpBody, let resultString = String(data: httpBody, encoding: .utf8) {
            printIfDebug("body: \(String(describing: resultString))")
        }
    }

    public func log(responseData data: Data?, response: URLResponse?) {
        guard let data = data else { return }
        if let dataDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            printIfDebug("responseData: \(String(describing: dataDict))")
        }
    }

    public func log(error: Error) {
        printIfDebug("\(error)")
    }
}

// MARK: - NetworkError extension

extension NetworkError {
    public var isNotFoundError: Bool { return hasStatusCode(404) }
    
    public func hasStatusCode(_ codeError: Int) -> Bool {
        switch self {
        case let .error(code, _):
            return code == codeError
        default: return false
        }
    }
}

func printIfDebug(_ string: String) {
    #if DEBUG
    print(string)
    #endif
}
