//
//  Defaults.swift
//  ZCode
//
//  Created by Guy on 07/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation
import AppKit

class Defaults {
    static let userDefaults = UserDefaults(suiteName: "J8ZST4AX3A.com.houzz.zcode")!

    public class func register() {
        let def: [String: Any] = [
            "nil": true,
            "upper": true,
            "logger": true
        ]
        userDefaults.register(defaults: def)
    }

    static var nilEmptyStrings: Bool {
        get {
            return userDefaults.bool(forKey: "nil")
        }
        set {
            userDefaults.set(newValue, forKey: "nil")
        }
    }

    static var upperCase: Bool {
        get {
            return userDefaults.bool(forKey: "upper")
        }
        set {
            userDefaults.set(newValue, forKey: "upper")
        }
    }

    static var useLogger: Bool {
        get {
            return userDefaults.bool(forKey: "logger")
        }
        set {
            userDefaults.set(newValue, forKey: "logger")
        }
    }

}
