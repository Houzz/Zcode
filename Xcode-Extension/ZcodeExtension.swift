//
//  ZcodeExtension.swift
//  XCodeExtension
//
//  Created by Guy on 27/04/2018.
//  Copyright © 2018 Houzz. All rights reserved.
//

import Foundation
import XcodeKit

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    private var zcode: SourceZcodeCommand?
    //    var edits = [EditOperation]()

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        if let message = SourceEditorExtension.updateMessage {
            let error = NSError(domain: "ZCode", code: 200, userInfo: [NSLocalizedDescriptionKey: message])
            completionHandler(error)
            return
        }

        let source = XcodeSource(source: invocation.buffer, completion: completionHandler)

        if invocation.buffer.contentUTI as CFString != kUTTypeSwiftSource  {
            source.finish(error: CommandError.onlySwift)
            return
        }


        let options:CommandOptions
        switch invocation.commandIdentifier {
        case "assertOutlets":
            options = .assert

        case "cast":
            options = .cast

        case "read":
            options = .read

        case "copy":
            options = .copying

        case "nscoding":
            options = .coding

        case "customInit":
            options = .customInit

        case "default":
            options = .defaults

        case "multipart":
            options = .multipart
            
        default:
            completionHandler(CommandError.unknown.error)
            return
        }
        zcode = SourceZcodeCommand(source: source, options: options)
        zcode?.perform()
    }
}

extension SourcePosition {
    init(_ p: XCSourceTextPosition) {
        line = p.line
        column = p.column
    }
}

class XcodeSource : ZcodeCommand {
    var linePos: Int = 0
    var source: XCSourceTextBuffer
    var completionHandler: ((Error?) -> Void)?

    init(source: XCSourceTextBuffer, completion: @escaping (Error?) -> Void) {
        self.source = source
        self.completionHandler = completion
    }

    func moveCursor(toLine line: Int, column: Int) {
        let pos = XCSourceTextPosition(line: line, column: column)
        source.selections[0] = XCSourceTextRange(start: pos, end: pos)
    }

    func finish(error: CommandError? = nil) {
        completionHandler?(error?.error)
        completionHandler = nil
    }

    var lineCount: Int {
        return source.lines.count
    }

    func line(_ idx: Int) -> String {
        return source.lines[idx] as! String
    }

    func selectLines(from: Int, count: Int) {
        let start = XCSourceTextPosition(line: from, column: 0)
        let end = XCSourceTextPosition(line: from + count, column: 0)
        let sel = XCSourceTextRange(start: start, end: end)
        source.selections.add(sel)
    }


    var cursorPosition: SourcePosition {
        return SourcePosition((source.selections[0] as! XCSourceTextRange).start)
    }

    func deleteLines(from: Int, to: Int) {
        for i in (from ..< to).reversed() {
            source.lines.removeObject(at: i)
            if linePos > i {
                linePos -= 1
            }
        }
    }

    func insert(_ newlines: [String], at idx: Int, select: Bool = true) {
        var insertion = idx
        for line in newlines {
            source.lines.insert(line, at: insertion)
            if linePos >= insertion {
                linePos += 1
            }
            insertion += 1
        }
        if select {
            selectLines(from: idx, count: newlines.count)
        }
    }

    func indentationString(level: Int) -> String {
        var cache = [Int:String]()
        if let s = cache[level] {
            return s
        }
        var prefix = String(repeating: " ", count: level * source.indentationWidth)
        if source.usesTabsForIndentation {
            let replaceWithTab = String(repeating: " ", count: source.tabWidth)
            while prefix.contains(replaceWithTab) {
                prefix = prefix.replacingOccurrences(of: replaceWithTab, with: "\t")
            }
        }
        cache[level] = prefix
        return prefix
    }
}
