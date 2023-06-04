//
//  Extensions.swift
//  ZCode
//
//  Created by Guy on 02/06/2018.
//  Copyright © 2018 Houzz. All rights reserved.
//

import Foundation


public protocol StringMatchable {
    func match(_ str: String) -> Bool
}

/// Usage: case includes("word"):
public struct includes: StringMatchable {
    let value: String
    let caseInsensitive: Bool
    public init(_ sub: String, caseInsensitive: Bool = false) {
        self.caseInsensitive = caseInsensitive
        value = caseInsensitive ? sub.lowercased() : sub
    }
    public func match(_ str: String) -> Bool {
        switch caseInsensitive {
        case false:
            return str.contains(value)

        case true:
            return str.lowercased().contains(value)
        }
    }
}

/// usage: case endsWith("."):
public struct endsWith: StringMatchable {
    public func match(_ str: String) -> Bool {
        return str.hasSuffix(value)
    }

    let value: String
    public init(_ suffix: String) {
        value = suffix
    }
}


/// Usage: case startsWith("a"):
public struct startsWith: StringMatchable {
    public func match(_ str: String) -> Bool {
        return str.hasPrefix(value)
    }

    let value: String
    public init(_ prefix: String) {
        value = prefix
    }
}

public struct CaseInsensitive: StringMatchable {
    public func match(_ str: String) -> Bool {
        return str.caseInsensitiveCompare(value) == .orderedSame
    }

    let value: String
    public init(_ str: String) {
        value = str
    }
}

public class matches : Regex {
    // no need to do anything, just so we can write case matches("a.*"):
}

extension String {
    public var caseInsensitive: CaseInsensitive {
        return CaseInsensitive(self)
    }
}

public func ~=<T: StringMatchable>(string: String, matchMaker: T) -> Bool {
    return matchMaker.match(string)
}

public func ~=<T: StringMatchable>(matchMaker: T, o: String?) -> Bool { // This one needed for switch/case pattern matching
    if let o = o {
        return matchMaker.match(o)
    }
    return false
}

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
}
