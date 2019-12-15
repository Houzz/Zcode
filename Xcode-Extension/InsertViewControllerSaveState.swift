//
//  InsertViewControllerSaveState.swift
//  ZCode
//
//  Created by Guy on 12/12/2019.
//  Copyright © 2019 Houzz. All rights reserved.
//

import Foundation


extension SourceZcodeCommand {
    func insertSaveState() {
        let conformRegex = Regex("(class|extension) .*ViewControllerSaveState.*\\{ *$", options: [.anchorsMatchLines])
        let accessRegex = Regex("(public|private|internal|open|fileprivate)")

        var override = true
        var access: String? = nil
        enumerateLines(skipBlank: false) { (in_lineIndex, line, braceLevel, priorBraceLevel, stop) in
            if braceLevel == 1 {
                if priorBraceLevel == 0 {
                    if conformRegex.match(line) {
                        override = false
                    } else {
                        override = true
                    }
                    if let matches: [String?] = accessRegex.matchGroups(line), !line.contains("extension") {
                        access = matches[1]
                    } else {
                        access = nil
                    }
                }
                if in_lineIndex >= cursorPosition.line  {
                    insertCode(at: in_lineIndex + 1, override: override, access: access)
                    stop = true
                }
            }
        }
        finish()
    }
    
    private func insertCode(at index: Int, override: Bool, access: String?) {
        var code = [String]()
        var accessString: String = {
            switch access {
            case .none:
                return ""
                
            case .some("open"):
                return "public"
                
            case .some("private"):
                return "fileprivate"
                
            case  .some(let x):
                return x
            }
        }()
        
        let open = "<#"
        let close = "#>"
        if !accessString.isEmpty {
            accessString += " "
        }
        code.append("\(indentationString(level: 1))private enum CodingKeys: String, CodingKey {")
        code.append("\(indentationString(level: 2))case \(open)key\(close)")
        code.append("\(indentationString(level: 1))}")
        code.append("")
        code.append("\(indentationString(level: 1))\(accessString)\(override ? "override " : "")func saveState(to encoder: Encoder) throws {")
        code.append("\(indentationString(level: 2))var container = encoder.container(keyedBy: CodingKeys.self)")
        code.append("\(indentationString(level: 2))// Encode view controller state here")
        code.append("\(indentationString(level: 2))\(open)code\(close)")
        if override {
            code.append("\(indentationString(level: 2))try super.saveState(to: encoder)")
        }
        code.append("\(indentationString(level: 1))}")
        code.append("")
        code.append("\(indentationString(level: 1))\(accessString)\(override ? "override " : "")func restoreState(from decoder: Decoder) throws {")
        code.append("\(indentationString(level: 2))let container = try decoder.container(keyedBy: CodingKeys.self)")
        code.append("\(indentationString(level: 2))// Decode view controller state here")
        code.append("\(indentationString(level: 2))// View is not yet loaded, insert _ = view if need to load view")
        code.append("\(indentationString(level: 2))\(open)code\(close)")
        if override {
            code.append("\(indentationString(level: 2))try super.restoreState(from: decoder)")
        }
        code.append("\(indentationString(level: 1))}")
        code.append("")
        code.append("\(indentationString(level: 1))// return a view controller, don't call restore on it, if this is a superclass that is not supposed to be saved")
        code.append("\(indentationString(level: 1))// directly, can omit implementing this function")
        code.append("\(indentationString(level: 1))\(accessString)\(override ? "override " : "")class func viewController(using decoder: Decoder) throws -> UIViewController {")
        code.append("\(indentationString(level: 2))\(open)code\(close)")
        code.append("\(indentationString(level: 1))}")
        insert(code, at: index, select: false)
    }
}
