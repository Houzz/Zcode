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

    var lineCount: Int {
        return source.lineCount
    }

    func perform() {
        if options.contains(.assert) {
            assertOutlets()
        }
        if !options.isDisjoint(with: [.cast, .read, .copying, .coding, .customInit, .multipart]) {
            cast(command: options)
        }
        if options.contains(.defaults) {
            makeDefaults()
        }
        if options.contains(.codable) {
            codable()
        }
        if options.contains(.saveState) {
            insertSaveState()
        }
    }

    /// finish the command - must be called at end of command
    ///
    /// - Parameter error: an optional error to send to XCode.
    func finish(error: CommandError? = nil) {
        source.finish(error: error)
    }

    /// Select lines in Xcode. Lines will be selected in xcode.
    ///
    /// - Parameters:
    ///   - from: line index
    ///   - count: number of lines to select
    func selectLines(from: Int, count: Int) {
        source.selectLines(from: from, count: count)
    }

    /// Move the Xcode cursor
    ///
    /// - Parameters:
    ///   - line: line index
    ///   - column: character in line
    func moveCursor(toLine line: Int, column: Int) {
        source.moveCursor(toLine: line, column: column)
    }

    /// return the current Xcode cursor position
    var cursorPosition: SourcePosition {
        return source.cursorPosition
    }

    /// Delete source lines
    ///
    /// - Parameters:
    ///   - from: line index
    ///   - to: line index
    func deleteLines(from: Int, to: Int) {
        source.deleteLines(from: from, to: to)
    }

    func append(_ line: String) {
        source.append(line)
    }

    /// Insert lines
    ///
    /// - Parameters:
    ///   - newlines: array of lines to insert
    ///   - idx: Index to insert lines
    ///   - select: if true inserted lines are selected
    func insert(_ newlines: [String], at idx: Int, select: Bool = true) {
        source.insert(newlines, at: idx, select: select)
    }

    /// indentation string taking into consideration file indentation format
    ///
    /// - Parameter level: level of indenetation, e.g. 1 is in a class, 2 is in in a func in a class, etc.
    /// - Returns: string to use to get to this level of indentation.
    func indentationString(level: Int) -> String {
        return source.indentationString(level:level)
    }

    /// iterate over all source lines
    ///
    /// - Parameter handler: Block to run on each line, the function will automatically skip comments, it gets the following parameters: the line index, the line, the current brace level and the previous line brace level and a stop flag, if set to true by the block iteration is stopped.
    func enumerateLines(skipBlank: Bool = true, withBlock handler: (_ lineIndex: Int, _ line: String, _ braceLevel: Int, _ previousBraceLevel: Int, _ stop: inout Bool) -> Void) {
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
            if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty && skipBlank {
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

