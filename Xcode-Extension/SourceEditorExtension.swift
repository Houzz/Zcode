//
//  SourceEditorExtension.swift
//  AssertOutlets
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    

    func extensionDidFinishLaunching() {
        Defaults.register()
    }


//    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
//        // If your extension needs to return a collection of command definitions that differs from those in its Info.plist, implement this optional property getter.
//        return []
//    }

}
