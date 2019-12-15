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

private var lastCheck:TimeInterval = 0
func checkForUpdate() -> Release? {
    guard let url = URL(string: "https://api.github.com/repos/houzz/zcode/releases"), CFAbsoluteTimeGetCurrent() - lastCheck > 3600 else {
        return nil
    }
    lastCheck = CFAbsoluteTimeGetCurrent()
    guard let data = try? Data(contentsOf: url),
        let root = try? JSONSerialization.jsonObject(with: data, options: []) as? [JSONDictionary],
        let latestInfo = root?.first,
        let latest = Release(dictionary: latestInfo),
        let currentVerionString = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        else {
            return nil
    }
    let current = Version(currentVerionString)
    if latest.version > current {
        return latest
    }
    return nil
}

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
        let a1 = lhs.element + [0,0]
        let a2 = rhs.element + [0,0]
        let vlhs = a1[0] * 1000000 + a1[1] * 1000 + a1[2]
        let vrhs = a2[0] * 1000000 + a2[1] * 1000 + a2[2]
        print("\(vlhs) < \(vrhs)")
        return vlhs < vrhs
    }

    static func > (lhs: Version, rhs: Version) -> Bool {
        let a1 = lhs.element + [0,0]
        let a2 = rhs.element + [0,0]
        let vlhs = a1[0] * 1000000 + a1[1] * 1000 + a1[2]
        let vrhs = a2[0] * 1000000 + a2[1] * 1000 + a2[2]
        print("\(vlhs) > \(vrhs)")
        return vlhs > vrhs
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

