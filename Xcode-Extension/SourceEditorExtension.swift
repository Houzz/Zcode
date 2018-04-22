//
//  SourceEditorExtension.swift
//  AssertOutlets
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation
import XcodeKit

extension Int {
    var days: TimeInterval {
        return TimeInterval(self * 86400)
    }
}

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    public static var updateMessage: String? = nil
    public static var repeater: Repeater? = nil

    func extensionDidFinishLaunching() {
        Defaults.register()
        checkForUpdate()
        if SourceEditorExtension.updateMessage == nil {
            SourceEditorExtension.repeater = Repeater.every(3.days, perform: { (sender) in
                self.checkForUpdate()
                if SourceEditorExtension.updateMessage != nil {
                    sender.cancel()
                }
            })
        }
    }

    func checkForUpdate() {
        guard let url = URL(string: "https://api.github.com/repos/houzz/zcode/releases") else {
            return
        }
        guard let data = try? Data(contentsOf: url),
            let root = try? JSONSerialization.jsonObject(with: data, options: []) as? [JSONDictionary],
            let latestInfo = root?.first,
            let latest = Release(dictionary: latestInfo),
            let currentVerionString = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            else {
                return
        }
        let current = Version(currentVerionString)
        if latest.version > current {
            SourceEditorExtension.updateMessage =  "Please update to version \(latest.version.display) from https://github.com/houzz/zcode/releases"
        }
    }
}
