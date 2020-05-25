//
//  XMLEncodingStorage.swift
//  XMLParsing
//
//  Created by Prashant Shrestha on 8/11/18.
//  Copyright © 2018 Prashant Shrestha. All rights reserved.
//

import Foundation

// MARK: - Encoding Storage and Containers

internal struct _XMLEncodingStorage {
    // MARK: Properties
    
    /// The container stack.
    /// Elements may be any one of the XML types (NSNull, NSNumber, NSString, NSArray, NSDictionary).
    private(set) internal var containers: [NSObject] = []
    
    // MARK: - Initialization
    
    /// Initializes `self` with no containers.
    internal init() {}
    
    // MARK: - Modifying the Stack
    
    internal var count: Int {
        return self.containers.count
    }
    
    internal mutating func pushKeyedContainer() -> NSMutableDictionary {
        let dictionary = NSMutableDictionary()
        self.containers.append(dictionary)
        return dictionary
    }
    
    internal mutating func pushUnkeyedContainer() -> NSMutableArray {
        let array = NSMutableArray()
        self.containers.append(array)
        return array
    }
    
    internal mutating func push(container: NSObject) {
        self.containers.append(container)
    }
    
    internal mutating func popContainer() -> NSObject {
        precondition(self.containers.count > 0, "Empty container stack.")
        return self.containers.popLast()!
    }
}
