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
    case cast, read, copy, nscoding, customInit
}

extension Command {
    func isOneOf(_ args: Command...) -> Bool {
        return args.contains(self)
    }
}

class SourceEditorCommand: NSObject, XCSourceEditorCommand {
    var source: XCSourceTextBuffer!

    private var completionHandler: ((Error?) -> Void)?
//    var edits = [EditOperation]()
    private var linePos: Int = 0

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void ) -> Void {
        guard let command = Command(rawValue: invocation.commandIdentifier) else {
            completionHandler(CommandError.unknown.error)
            return
        }

        source = invocation.buffer
        self.completionHandler = completionHandler

        if let message = SourceEditorExtension.updateMessage {
            finish(updateMessage: message)
            return
        }

        switch command {
        case .assertOutlets:
            assertOutlets()

        case .cast, .read, .copy, .nscoding, .customInit:
            cast(command: command)
        }
    }

    func finish(error: CommandError? = nil) {
        source = nil
        completionHandler?(error?.error)
        completionHandler = nil
    }

    func finish(updateMessage: String) {
        source = nil
        let error = NSError(domain: "ZCode", code: 200, userInfo: [NSLocalizedDescriptionKey: updateMessage])
        completionHandler?(error)
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

    var cursorPosition: XCSourceTextPosition {
        return (source.selections[0] as! XCSourceTextRange).start
    }

    func deleteLines(from: Int, to: Int) {
        for i in (from ..< to).reversed() {
            source.lines.removeObject(at: i)
            if linePos + 1 >= i {
                linePos -= i
            }
        }
    }

    func insert(_ newlines: [String], at idx: Int, select: Bool = true) {
        var insertion = idx
        for line in newlines {
            source.lines.insert(line, at: insertion)
            insertion += 1
            if linePos + 1 >= insertion {
                linePos += 1
            }
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



    func enumerateLines(withBlock handler: (_ lineIndex: Int, _ line: String, _ braceLevel: Int, _ previousBraceLevel: Int, _ stop: inout Bool) -> Void) {
        var braceLevel = 0
        var previousBraceLevel = 0
        var stop = false
        var inCComment = false
        var inString = false
        enum State {
            case code
            case string
            case ccomment
        }
        var state = State.code
        while linePos < source.lines.count {
            defer {
                linePos += 1
            }
            let line = source.lines[linePos] as! String
            if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty  {
                continue
            }

            var i = 0
            let count = line.count
            let currentBraceLevel = braceLevel
            out: while i < count {
                defer {
                    i += 1
                }

                switch state {
                case .code:
                    switch line[i] {
                    case "\"":
                        state = .string

                    case "/":
                        if line[i+1] == "/" {
                            break out
                        } else if line[i+1] == "*" {
                            state = .ccomment
                        }

                    case "{":
                        braceLevel += 1

                    case "}":
                        braceLevel -= 1

                    default:
                        break
                    }

                case .string:
                    if line[i] == "\\" {
                        i += 1
                    } else if line[i] == "\"" {
                        state = .code
                    }

                case .ccomment:
                    if line[i] == "*" && line[i+1] == "/" {
                        i += 1
                        state = .code
                    }
                }
            }

            handler(linePos, line.trimTrailingWhitespace(), braceLevel, previousBraceLevel, &stop)
            if stop {
                break
            }
            previousBraceLevel = braceLevel
        }
    }
}

extension String {
    func trimTrailingWhitespace() -> String {
        if let trailingWs = self.range(of: "\\s+$", options: .regularExpression) {
            return self.replacingCharacters(in: trailingWs, with: "")
        } else {
            return self
        }
    }
}

