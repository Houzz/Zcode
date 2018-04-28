//
//  SourceEditorCommand.swift
//  AssertOutlets
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation

class SourceZcodeCommand {
    var source: ZcodeCommand
    let options: CommandOptions
    private var linePos: Int {
        get {
            return source.linePos
        }
        set {
            source.linePos = newValue
        }
    }

    init(source: ZcodeCommand, options: CommandOptions) {
        self.source = source
        self.options = options
    }

    func perform() {
        if options.contains(.assert) {
            assertOutlets()
        }
        if !options.isDisjoint(with: [.cast, .read, .copying, .coding, .customInit]) {
            cast(command: options)
        }
        if options.contains(.defaults) {
            makeDefaults()
        }
    }

    func finish(error: CommandError? = nil) {
        source.finish(error: error)
    }

    func selectLines(from: Int, count: Int) {
        source.selectLines(from: from, count: count)
    }

    func moveCursor(toLine line: Int, column: Int) {
        source.moveCursor(toLine: line, column: column)
    }

    var cursorPosition: SourcePosition {
        return source.cursorPosition
    }

    func deleteLines(from: Int, to: Int) {
        source.deleteLines(from: from, to: to)
    }

    func insert(_ newlines: [String], at idx: Int, select: Bool = true) {
        source.insert(newlines, at: idx, select: select)
    }

    func indentationString(level: Int) -> String {
        return source.indentationString(level:level)
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
        while linePos < source.lineCount {
            defer {
                linePos += 1
            }
            let line = source.line(linePos)
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

