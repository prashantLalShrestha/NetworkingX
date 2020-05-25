//
//  Endpoint.swift
//  NetworkingX
//
//  Created by Prashant Shrestha on 5/24/20.
//  Copyright © 2020 Inficare. All rights reserved.
//

import Foundation

public struct HTTPMethodType: RawRepresentable, Equatable, Hashable {
    public static let connect = HTTPMethodType(rawValue: "CONNECT")
    public static let delete = HTTPMethodType(rawValue: "DELETE")
    public static let get = HTTPMethodType(rawValue: "GET")
    public static let head = HTTPMethodType(rawValue: "HEAD")
    public static let options = HTTPMethodType(rawValue: "OPTIONS")
    public static let patch = HTTPMethodType(rawValue: "PATCH")
    public static let post = HTTPMethodType(rawValue: "POST")
    public static let put = HTTPMethodType(rawValue: "PUT")
    public static let trace = HTTPMethodType(rawValue: "TRACE")

    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public class Endpoint<R>: ResponseRequestable {

    public typealias Response = R

    public var path: String
    public var isFullPath: Bool
    public var method: HTTPMethodType
    public var headerParamaters: [String: String]
    public var queryParametersEncodable: Encodable? = nil
    public var queryParameters: [String: Any]
    public var bodyParamatersEncodable: Encodable? = nil
    public var bodyParamaters: [String: Any]
    public var bodyEncoding: ParameterEncoding
    public var responseDecoder: ResponseDecoder

    public init(path: String,
         isFullPath: Bool = false,
         method: HTTPMethodType,
         headerParamaters: [String: String] = [:],
         queryParametersEncodable: Encodable? = nil,
         queryParameters: [String: Any] = [:],
         bodyParamatersEncodable: Encodable? = nil,
         bodyParamaters: [String: Any] = [:],
         bodyEncoding: ParameterEncoding = JSONEncoding.default,
         responseDecoder: ResponseDecoder = JSONResponseDecoder()) {
        self.path = path
        self.isFullPath = isFullPath
        self.method = method
        self.headerParamaters = headerParamaters
        self.queryParametersEncodable = queryParametersEncodable
        self.queryParameters = queryParameters
        self.bodyParamatersEncodable = bodyParamatersEncodable
        self.bodyParamaters = bodyParamaters
        self.bodyEncoding = bodyEncoding
        self.responseDecoder = responseDecoder
    }
}

public protocol Requestable {
    var path: String { get }
    var isFullPath: Bool { get }
    var method: HTTPMethodType { get }
    var headerParamaters: [String: String] { get }
    var queryParametersEncodable: Encodable? { get }
    var queryParameters: [String: Any] { get }
    var bodyParamatersEncodable: Encodable? { get }
    var bodyParamaters: [String: Any] { get }
    var bodyEncoding: ParameterEncoding { get }

    func urlRequest(with networkConfig: NetworkConfigurable) throws -> URLRequest
}

public protocol ResponseRequestable: Requestable {
    associatedtype Response

    var responseDecoder: ResponseDecoder { get }
}

enum RequestGenerationError: Error {
    case components
    case invalidURL(url: URLConvertible)
    case parameterEncodingFailed
    case jsonEncodingFailed
    case xmlEncodingFailed
    case multipartEncodingFailed
}

extension Requestable {

    func url(with config: NetworkConfigurable) throws -> URL {

        let baseURL = config.baseURL.absoluteString.last != "/" ? config.baseURL.absoluteString + "/" : config.baseURL.absoluteString
        let endpoint = isFullPath ? path : baseURL.appending(path)

        guard var urlComponents = URLComponents(string: endpoint) else { throw RequestGenerationError.components }
        var urlQueryItems = [URLQueryItem]()

        let queryParameters = try queryParametersEncodable?.toDictionary() ?? self.queryParameters
        queryParameters.forEach {
            urlQueryItems.append(URLQueryItem(name: $0.key, value: "\($0.value)"))
        }
        config.queryParameters.forEach {
            urlQueryItems.append(URLQueryItem(name: $0.key, value: $0.value))
        }
        urlComponents.queryItems = !urlQueryItems.isEmpty ? urlQueryItems : nil
        guard let url = urlComponents.url else { throw RequestGenerationError.components }
        return url
    }

    public func urlRequest(with config: NetworkConfigurable) throws -> URLRequest {

        let url = try self.url(with: config)
        var urlRequest = URLRequest(url: url)
        var allHeaders: [String: String] = config.headers
        headerParamaters.forEach { allHeaders.updateValue($1, forKey: $0) }

        urlRequest.httpMethod = method.rawValue
        urlRequest.allHTTPHeaderFields = allHeaders
        
        let bodyParamaters = try bodyParamatersEncodable?.toDictionary() ?? self.bodyParamaters
        if !bodyParamaters.isEmpty {
            urlRequest = try bodyEncoding.encode(urlRequest, with: bodyParamaters)
        }
        return urlRequest
    }
}

private extension Dictionary {
    var queryString: String {
        return self.map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .addingPercentEncoding(withAllowedCharacters: NSCharacterSet.urlQueryAllowed) ?? ""
    }
}

private extension Encodable {
    func toDictionary() throws -> [String: Any]? {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let josnData = try JSONSerialization.jsonObject(with: data)
        return josnData as? [String : Any]
    }
}

