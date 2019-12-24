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
                return "open"
                
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
        code.append("\(indentationString(level: 1))override \(accessString) func saveState(to encoder: Any) throws {")
        code.append("\(indentationString(level: 2))guard let encoder = encoder as? Encoder else { return }")
        code.append("\(indentationString(level: 2))var container = encoder.container(keyedBy: CodingKeys.self)")
        code.append("\(indentationString(level: 2))\(open)Encode view controller state here\(close)")
        if override {
            code.append("\(indentationString(level: 2))try super.saveState(to: encoder)")
        }
        code.append("\(indentationString(level: 1))}")
        code.append("")
        code.append("\(indentationString(level: 1))override \(accessString) func restoreState(from decoder: Any) throws {")
        code.append("\(indentationString(level: 2))guard let decoder = decoder as? Decoder else { return }")
        code.append("\(indentationString(level: 2))let container = try decoder.container(keyedBy: CodingKeys.self)")
        code.append("\(indentationString(level: 2))// View is not yet loaded, insert _ = view if need to load view")
        code.append("\(indentationString(level: 2))\(open)Decode view controller state here\(close)")
        if override {
            code.append("\(indentationString(level: 2))try super.restoreState(from: decoder)")
        }
        code.append("\(indentationString(level: 1))}")
        code.append("")
        code.append("\(indentationString(level: 1))// return a view controller, don't call restore on it, if this is a superclass that is not supposed to be saved")
        code.append("\(indentationString(level: 1))// directly, can omit implementing this function if shouldSaveState return false")
        code.append("\(indentationString(level: 1))\(accessString)override class func viewController(using decoder: Any) throws -> UIViewController {")
        code.append("\(indentationString(level: 2))guard let decoder = decoder as? Decoder else { throw SaveStateError(.notStateDecoder) }")
        code.append("\(indentationString(level: 2))\(open)Create view controller here\(close)")
        code.append("\(indentationString(level: 1))}")
        code.append("")
        code.append("\(indentationString(level: 1))// Return if we should save state on this controller (can change during controller lifetime)")
        code.append("\(indentationString(level: 1))\(accessString)\(override ? "override " : "")var shouldSaveState: Bool { true }")
        insert(code, at: index, select: false)
    }
}
