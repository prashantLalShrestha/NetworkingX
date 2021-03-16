# NetworkingX


## Introduction

NetworkingX is a clean, lightweight framework for making HTTP requests built over the `URLSession` of `swift` language. The main objective of this framework is to separate the networking protocols in smaller steps, giving us extra flexibility in code management.


## Requirements

- iOS 10.0+ / macOS 10.12+ / tvOS 10.0+ / watchOS 3.0+
- Xcode 11+
- Swift 5.1+


## Installation

### CocoaPods

[CocoaPods](https://cocoapods.org) is a dependency manager for Cocoa projects. To install NetworkingX, simply add the following line to your `Podfile`:

```ruby
pod 'NetworkingX'
```

### Swift Package Manager

The [Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. NetworkingX also support its use on supported platforms.

Once you have your Swift package set up, adding NetworkingX as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/prashantLalShrestha/NetworkingX.git", .upToNextMajor(from: "1.3.0"))
]
```


## Usage

NetworkingX is  quite simple to use. However there are some of the protocols and classes to take notes of. 


### NetworkConfigurable

It is a protocol implemented to configure the base HTTP network configurations. This includes the base url of the hosted address, common headers and common query parameters.

```swift
public protocol NetworkConfigurable {
    var baseURL: URL { get }
    var headers: [String: String] { get }
    var queryParameters: [String: String] { get }
}
```

We can create an object from it's default implementation `ApiDataNetworkConfig`.
```swift
let config = ApiDataNetworkConfig(baseURL: URL(string: "https://url.to.api/"))
```

### NetworkService

A service protocols used to make HTTP requests. It's default implementation `DefaultNetworkService` wraps the `URLSession().dataTask` function. You can use this protocol to create your own implementation, for example, using `Alamofire`.

```swift
public protocol NetworkService {
    typealias CompletionHandler = (Result<Data?, NetworkError>) -> Void
    
    func request(endpoint: Requestable, completion: @escaping CompletionHandler) -> NetworkCallable?
}
```

The above made network `config` object is used in NetworkService. We can create a NetworkService object as:
```swift
let networkService = DefaultNetworkService(config: config)
```


### NetworkSessionManager
NetworkSessionManager works as an interceptor in between HTTP requests. We can use this protocol to maintain the access tokens, authentications.
```swift
public protocol NetworkSessionManager {
    var acceptableStatusCodes: [Int] { get }
    typealias CompletionHandler = (Data?, URLResponse?, Error?) -> Void
    
    func request(_ request: URLRequest,
                 completion: @escaping CompletionHandler) -> NetworkCallable
}
```

Typically, we use `NetworkSessionManager` in our `NetworkService` class.
```swift
let networkService = DefaultNetworkService(config: config, sessionManager: DefaultNetworkSessionManager())
```

### Endpoint
We create an endpoint for each network api calls. `Endpoint` implements the protocol `Requestable` 
```swift
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
```

As you can see in the above protocol, we will be defining our api call configurations in here. 
```swift
struct Endpoints {
    static func authenticateUser(request: UserAuthenticationRequest) -> Endpoint<UserAuthenticationResponse> {
        return Endpoint(path: "path/of/login",
                        method: .post,
                        bodyParamatersEncodable: request,
                        bodyEncoding: URLEncoding.default
        )
    }
}

```


### ParameterEncoding
A type used to define how a set of parameters are applied to a `URLRequest`. There are some inbuilt ParameterEncoding implementations in the framework.
 - URLEncoding
 - JSONEncoding
 - XMLEncoding
 - MultiPartEncoding
 
However, you can create your own Encoding implementation using this protocol and use it in your `Endpoint`.


### DataTransferService
DataTransferService is a place where most of the work is done with the help of `Endpoint`, `NetworkService` and `ErrorResolver`.
```swift
public protocol DataTransferService {
    typealias CompletionHandler<T> = (Result<T, DataTransferError>) -> Void
    
    @discardableResult
    func request<T: Decodable, E: ResponseRequestable>(with endpoint: E,
                                                       completion: @escaping CompletionHandler<T>) -> NetworkCallable? where E.Response == T
                                                       
    @discardableResult
    func request<E: ResponseRequestable>(with endpoint: E,
                                         completion: @escaping CompletionHandler<Void>) -> NetworkCallable? where E.Response == Void
}
```

For simplicity, you can use the default implementation `DefaultDataTransferService` as:
```swift
let dataTransferService = DefaultDataTransferService(with: networkService)
```


### DataTransferErrorResolver
It is used to resolve the `NetworkError` in the form of `DataTransferError`. We can create an implementation class for this protocol to map our errors.
```swift
public protocol DataTransferErrorResolver {
    func resolve(error: NetworkError) -> Error
}
```

And, use it in `DefaultDataTransferService` as:
```swift
let dataTransferService = DefaultDataTransferService(with: networkService,
                                                             errorResolver: DefaultDataTransferErrorResolver())
```

### Now the sweet part,
After setting up our `NetworkConfig`, `NetworkSessionManager`, `NetworkService`, `Endpoint`, `DataTransferService`, we are now ready to make our network request,
```swift
let request = UserAuthenticationRequest(userName: "username", loginPassword: "password")

let endpoint = Endpoints.authenticateUser(request: request)
let task = dataTransferService.request(with: endpoint) { result in
    switch result {
    case .success(let response):
        // TODO: Update UI 
    case .failure(let error):
        // TODO: Handle Errors in UI
    }
}
task?.resume()

```

The main objective of this framework is to separate the networking protocols in smaller steps, giving us extra flexibility in code management expecially in, `Clean Archgitecture`.

