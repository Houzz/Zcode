//
//  SourceEditorCommand.swift
//  AssertOutlets
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation
import XcodeKit

public enum CommandError: Int, Error {
    case onlySwift
    case unknown
    case noVDLorAFN

    var localizedDescription: String {
        switch self {
        case .onlySwift:
            return "Only Swift files are supported"

        case .unknown:
            return "Unknwon Error"

        case .noVDLorAFN:
            return "Need super.viewDidLoad() for UIViewController subclass or super.awakeFromNib() for UIView subclass"
        }
    }

    var error: NSError {
        return NSError(domain: "ZCode", code: rawValue + 100, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
    }
}

enum Command: String {
    case assertOutlets
}

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    var source: XCSourceTextBuffer!
    private var completionHandler: ((Error?) -> Void)!

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        guard let command = Command(rawValue: invocation.commandIdentifier) else {
            completionHandler(CommandError.unknown.error)
            return
        }

        source = invocation.buffer
        self.completionHandler = completionHandler

        switch command {
        case .assertOutlets:
            assertOutlets()
        }
    }

    func finish(error: CommandError? = nil) {
        source = nil
        completionHandler(error?.error)
        completionHandler = nil
    }

    func selectLines(from: Int, count: Int) {
        let start = XCSourceTextPosition(line: from, column: 0)
        let end = XCSourceTextPosition(line: from + count, column: 0)
        let sel = XCSourceTextRange(start: start, end: end)
        source.selections.add(sel)
    }

    func moveCursor(toLine line: Int, column: Int) {
        let pos = XCSourceTextPosition(line: line, column: column)
        source.selections[0] = XCSourceTextRange(start: pos, end: pos)
    }

    func deleteLines(from: Int, to: Int) {
        for i in (from ..< to).reversed() {
            source.lines.removeObject(at: i)
        }
    }

    func insert(_ newlines: [String], at idx: Int, select: Bool = true) {
        var insertion = idx
        for line in newlines {
            source.lines.insert(line, at: insertion)
            insertion += 1
        }
        if select {
        selectLines(from: idx, count: newlines.count)
        }
    }

    func indentationString(level: Int) -> String {
        var prefix = String(repeating: " ", count: level * source.indentationWidth)
        if source.usesTabsForIndentation {
            let replaceWithTab = String(repeating: " ", count: source.tabWidth)
            while prefix.contains(replaceWithTab) {
                prefix = prefix.replacingOccurrences(of: replaceWithTab, with: "\t")
            }
        }
        return prefix
    }



    func enumerateLines(withBlock handler: (_ lineIndex: Int, _ line: String, _ braceLevel: Int, _ stop: inout Bool) -> Void) {
        var braceLevel = 0
        var stop = false
        for lineIndex in 0 ..< source.lines.count {
            let line = source.lines[lineIndex] as! String
            braceLevel += line.countInstances(of: "{") - line.countInstances(of: "}")
            handler(lineIndex, line, braceLevel, &stop)
            if stop {
                break
            }
        }
    }
}


