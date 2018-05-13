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
        if let latest = checkForUpdate() {
            SourceEditorExtension.updateMessage = "Please update to version \(latest.version.display) from https://github.com/houzz/zcode/releases or launch the Zcode app to update"
        } else {
            SourceEditorExtension.repeater = Repeater.every(1.days, perform: { (sender) in
                if let latest = checkForUpdate() {
                    sender.cancel()
                    SourceEditorExtension.updateMessage = "Please update to version \(latest.version.display) from https://github.com/houzz/zcode/releases or launch the Zcode app to update"
                }
            })
        }
    }
}
