//
//  XMLKey.swift
//  XMLParsing
//
//  Created by Prashant Shrestha on 8/11/18.
//  Copyright © 2018 Prashant Shrestha. All rights reserved.
//

import Foundation

//===----------------------------------------------------------------------===//
// Shared Key Types
//===----------------------------------------------------------------------===//

internal struct _XMLKey : CodingKey {
    public var stringValue: String
    public var intValue: Int?

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    public init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
    
    public init(stringValue: String, intValue: Int?) {
        self.stringValue = stringValue
        self.intValue = intValue
    }

    internal init(index: Int) {
        self.stringValue = "Index \(index)"
        self.intValue = index
    }

    internal static let `super` = _XMLKey(stringValue: "super")!
}


