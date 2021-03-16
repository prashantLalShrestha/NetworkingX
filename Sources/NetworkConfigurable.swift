//
//  NetworkConfigurable.swift
//  NetworkingX
//
//  Created by Prashant Shrestha on 5/24/20.
//  Copyright © 2020 Prashant Shrestha. All rights reserved.
//

import Foundation

/**
 A protocol to base configure network calls.
 
 You use this protocol  place base URL, initial headers with common access keys for api calls, and initial common query parameters.
 
 # Usage:
 You pass an object of NetworkConfigurable in NetworkService class implementation.
 */
public protocol NetworkConfigurable {
    var baseURL: URL { get }
    var headers: [String: String] { get }
    var queryParameters: [String: String] { get }
}

/**
 A default implementation class for protocol: NetworkConfigurable.
 
 
 # Usage:
 This default implementaion is used in DefaultNetworkService init function.
 */
public struct ApiDataNetworkConfig: NetworkConfigurable {
    public let baseURL: URL
    public let headers: [String: String]
    public let queryParameters: [String: String]
    
    
    /// Initializer
    /// - Parameters:
    ///   - baseURL: URL for hosted api address.
    ///   - headers: default headers in api calls.
    ///   - queryParameters: common query parameter in api calls. For Example: languageCode
    public init(baseURL: URL,
                 headers: [String: String] = [:],
                 queryParameters: [String: String] = [:]) {
        self.baseURL = baseURL
        self.headers = headers
        self.queryParameters = queryParameters
    }
}
