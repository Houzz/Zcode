//
//  Release.swift
//  XCodeExtension
//
//  Created by Guy on 22/04/2018.
//  Copyright © 2018 Houzz. All rights reserved.
//! Zcode: Case snake
//! Zcode: Logger off
//! Zcode: EmptyIsNil off

import Foundation

struct Release: DictionaryConvertible {
    let htmlUrl: String
    let tagName: String

    init?(dictionary dict: JSONDictionary) { // Generated
        if let v:String = dict.value(for: "html_url") {
            htmlUrl = v
        } else {
            return nil
        }
        if let v:String = dict.value(for: "tag_name") {
            tagName = v
        } else {
            return nil
        }
        if !awake(with: dict) {
            return nil
        }
    }

    func dictionaryRepresentation() -> [String: Any] { // Generated
        var dict = [String: Any]()
        if let x = htmlUrl.jsonValue {
            dict["html_url"] = x
        }
        if let x = tagName.jsonValue {
            dict["tag_name"] = x
        }
        // Add custom code after this comment
        return dict
    }
}

struct Version: Comparable {
    let element: [Int]

    static func < (lhs: Version, rhs: Version) -> Bool {
        for (i,v) in lhs.element.enumerated() {
            if v < (i < rhs.element.count ? rhs.element[i] : 0) {
                return true
            }
        }
        return rhs.element.count > lhs.element.count
    }

    static func > (lhs: Version, rhs: Version) -> Bool {
        for (i,v) in lhs.element.enumerated() {
            if v > (i < rhs.element.count ? rhs.element[i] : 0) {
                return true
            }
        }
        return lhs.element.count > rhs.element.count
    }

    var display: String {
        return element.map { "\($0)" }.joined(separator: ".")
    }

    init(_ str: String) {
        element = str.trimmingCharacters(in: .letters).components(separatedBy: ".").compactMap { Int($0) }
    }
}

extension Release {
    var version: Version {
        get {
            return Version(tagName)
        }
    }

    func awake(with dictionary: JSONDictionary) -> Bool {
        if let prerelease: Bool = dictionary.value(for: "prerelease") {
            return !prerelease
        }
        return true
    }
}

