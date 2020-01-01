//
//  Defaults.swift
//  ZCode
//
//  Created by Guy on 07/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation
import AppKit

public enum CaseType: String {
    case none
    case upper
    case snake
    case screamingSnake

    public init?(rawValue: String) {
        switch rawValue {
        case "upper".caseInsensitive, "CamelCase":
            self = .upper

        case "snake".caseInsensitive:
            self = .snake

        case "none".caseInsensitive, "lower".caseInsensitive, "default".caseInsensitive, "camelCase":
            self = .none

        case "screamingSnake".caseInsensitive:
            self = .screamingSnake

        default:
            return nil
        }
    }
}

class Defaults {
    static let userDefaults = UserDefaults(suiteName: "J8ZST4AX3A.com.houzz.zcode")!
    public enum Keys {
        case nilStrings
        case keyCase
        case useLogger
        case dictionaryCase
    }
    public static var sessionOverride = [Keys: Any]()

    public class func register() {
        let def: [String: Any] = [
            "nil": true,
            "case": CaseType.upper.rawValue,
            "logger": true
        ]
        userDefaults.register(defaults: def)
    }

    static var nilEmptyStrings: Bool {
        get {
            return sessionOverride[.nilStrings] as? Bool ?? userDefaults.bool(forKey: "nil")
        }
        set {
            userDefaults.set(newValue, forKey: "nil")
        }
    }

    static var keyCase: CaseType {
        get {
            return sessionOverride[.keyCase] as? CaseType ?? CaseType(rawValue: userDefaults.object(forKey: "case") as? String ?? "none")!
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: "case")
        }
    }

    static var useLogger: Bool {
        get {
            return sessionOverride[.useLogger] as? Bool ?? userDefaults.bool(forKey: "logger")
        }
        set {
            userDefaults.set(newValue, forKey: "logger")
        }
    }
    
    static var dictionaryCase: CaseType {
        get {
            return sessionOverride[.dictionaryCase] as? CaseType ?? CaseType(rawValue: userDefaults.object(forKey: "case") as? String ?? "") ?? sessionOverride[.keyCase] as? CaseType ?? CaseType(rawValue: userDefaults.object(forKey: "case") as? String ?? "none")!
        }
        set {
            userDefaults.set(newValue.rawValue, forKey: "case")
        }
    }

}
