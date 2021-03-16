//
//  DataTransferService.swift
//  NetworkingX
//
//  Created by Prashant Shrestha on 5/24/20.
//  Copyright © 2020 Prashant Shrestha. All rights reserved.
//

import Foundation

/**
 A common error representation for DataTransferService protocol.
 
 On using `DataTransferService` protocol for network calls, please use `DataTransferError` to represent any errors for commonality.
 */
public enum DataTransferError: Error {
    case noResponse
    case parsing(Error)
    case networkFailure(NetworkError)
    case resolvedNetworkFailure(Error)
}

/**
 A protocol service for network data calls.
 */
public protocol DataTransferService {
    typealias CompletionHandler<T> = (Result<T, DataTransferError>) -> Void
    
    /// initiates network request  using NetworkService protocol.
    /// - Parameters:
    ///   - endpoint: request `Endpoint`
    ///   - completion: result of network request completion. On success, the data is parsed in `T: Decodable` type. On failure, errors are resolved to `DataTransferError` case.
    /// - returns: a NetworkCallable object which is basically URLSessionTask. Typically, you can use it to resume, cancel, suspend the network requests.
    @discardableResult
    func request<T: Decodable, E: ResponseRequestable>(with endpoint: E,
                                                       completion: @escaping CompletionHandler<T>) -> NetworkCallable? where E.Response == T
    
    /// initiates network request  using NetworkService protocol.
    /// - Parameters:
    ///   - endpoint: request `Endpoint`
    ///   - completion: result of network request completion. On success, `Void` is returned. On failure, errors are resolved to `DataTransferError` case.
    /// - returns: a NetworkCallable object which is basically URLSessionTask. Typically, you can use it to resume, cancel, suspend the network requests.
    @discardableResult
    func request<E: ResponseRequestable>(with endpoint: E,
                                         completion: @escaping CompletionHandler<Void>) -> NetworkCallable? where E.Response == Void
}

/**
 A protocol used for resolving the Data TransferErrors. This is also a mapper to map other Errors to common DataTransferError.
 */
public protocol DataTransferErrorResolver {
    
    /// A mapper function to map NetworkErrors to DataTransferErrors.
    /// - Parameter error: NetworkError object. This usually comes from NetworkService as DataTransferService internally uses NetworkService for network requests.
    func resolve(error: NetworkError) -> Error
}

/**
 A decoder protocol used to implement decoding function for `Data`.
 */
public protocol ResponseDecoder {
    
    /// decodes the `Data` object to Decodable `T` object
    /// - Parameter data: data object.
    /// - Throws: decoding errors.
    func decode<T: Decodable>(_ data: Data) throws -> T
}

/**
 A protocol used to log any errors occured in data transfer protocols.
 
 # Usage:
 You can find it's usage in DataTransferService implementation classes.
 */
public protocol DataTransferErrorLogger {
    
    /// log DataTransferSevice Errors
    /// - Parameter error: Error of type `DataTransferError`
    func log(error: Error)
}

/**
 A default implementation of `DataTransferService`
 */
public final class DefaultDataTransferService {

    private let networkService: NetworkService
    private let errorResolver: DataTransferErrorResolver
    private let errorLogger: DataTransferErrorLogger

    
    /// `DefaultDataTransferService` Initializers`
    /// - Parameters:
    ///   - networkService: `NetworkService` object. It comprises network configs, session managers.
    ///   - errorResolver: `DataTransferErrorResolver` object. default value is provided. You can also create your own `ErrorResolver` and pass on it.
    ///   - errorLogger: `DataTransferErrorLogger` object.
    public init(with networkService: NetworkService,
                errorResolver: DataTransferErrorResolver = DefaultDataTransferErrorResolver(),
                errorLogger: DataTransferErrorLogger = DefaultDataTransferErrorLogger()) {
        self.networkService = networkService
        self.errorResolver = errorResolver
        self.errorLogger = errorLogger
    }
}

extension DefaultDataTransferService: DataTransferService {

    public func request<T: Decodable, E: ResponseRequestable>(with endpoint: E,
                                                              completion: @escaping CompletionHandler<T>) -> NetworkCallable? where E.Response == T {

        return self.networkService.request(endpoint: endpoint) { result in
            switch result {
            case .success(let data):
                let result: Result<T, DataTransferError> = self.decode(data: data, decoder: endpoint.responseDecoder)
                DispatchQueue.main.async { return completion(result) }
            case .failure(let error):
                self.errorLogger.log(error: error)
                let error = self.resolve(networkError: error)
                DispatchQueue.main.async { return completion(.failure(error)) }
            }
        }
    }

    public func request<E>(with endpoint: E, completion: @escaping CompletionHandler<Void>) -> NetworkCallable? where E : ResponseRequestable, E.Response == Void {
        return self.networkService.request(endpoint: endpoint) { result in
            switch result {
            case .success:
                DispatchQueue.main.async { return completion(.success(())) }
            case .failure(let error):
                self.errorLogger.log(error: error)
                let error = self.resolve(networkError: error)
                DispatchQueue.main.async { return completion(.failure(error)) }
            }
        }
    }

    // MARK: - Private
    private func decode<T: Decodable>(data: Data?, decoder: ResponseDecoder) -> Result<T, DataTransferError> {
        do {
            guard let data = data else { return .failure(.noResponse) }
            let result: T = try decoder.decode(data)
            return .success(result)
        } catch {
            self.errorLogger.log(error: error)
            return .failure(.parsing(error))
        }
    }

    private func resolve(networkError error: NetworkError) -> DataTransferError {
        let resolvedError = self.errorResolver.resolve(error: error)
        if let resolvedError = resolvedError as? NetworkError {
            return .networkFailure(resolvedError)
        } else {
            return .resolvedNetworkFailure(resolvedError)
        }
    }
}

// MARK: - Logger
public final class DefaultDataTransferErrorLogger: DataTransferErrorLogger {
    public init() { }

    public func log(error: Error) {
        printIfDebug("-------------")
        printIfDebug("\(error)")
    }
}

// MARK: - Error Resolver
public class DefaultDataTransferErrorResolver: DataTransferErrorResolver {
    public init() { }
    public func resolve(error: NetworkError) -> Error {
        return error
    }
}

// MARK: - Response Decoders
public class JSONResponseDecoder: ResponseDecoder {
    private let jsonDecoder = JSONDecoder()
    public init() { }
    public func decode<T: Decodable>(_ data: Data) throws -> T {
        return try jsonDecoder.decode(T.self, from: data)
    }
}

public class RawDataResponseDecoder: ResponseDecoder {
    public init() { }

    enum CodingKeys: String, CodingKey {
        case `default` = ""
    }
    public func decode<T: Decodable>(_ data: Data) throws -> T {
        if T.self is Data.Type, let data = data as? T {
            return data
        } else {
            let context = DecodingError.Context(codingPath: [CodingKeys.default], debugDescription: "Expected Data type")
            throw Swift.DecodingError.typeMismatch(T.self, context)
        }
    }
}

public class XMLResponseDecoder: ResponseDecoder {
    private let xmlDecoder = XMLDecoder()
    public init() { }
    public func decode<T>(_ data: Data) throws -> T where T : Decodable {
        return try xmlDecoder.decode(T.self, from: data)
    }
}



#if swift(>=5.0)
import Combine

@available(iOS 13.0, OSX 10.15, tvOS 13.0, watchOS 6.0, *)
public extension DataTransferService {
    
    func request<T: Decodable, E: ResponseRequestable>(with endpoint: E) -> AnyPublisher<T, DataTransferError> where E.Response == T {
        return Future() { self.request(with: endpoint, completion: $0) }.eraseToAnyPublisher()
    }
    
    func request<E: ResponseRequestable>(with endpoint: E) -> AnyPublisher<Void, DataTransferError> where E.Response == Void {
        return Future() { self.request(with: endpoint, completion: $0) }.eraseToAnyPublisher()
    }
}
#endif
