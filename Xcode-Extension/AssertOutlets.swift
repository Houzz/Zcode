//
//  AssertOutlets.swift
//  XCodeExtension
//
//  Created by Guy on 04/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation
import XcodeKit

extension String {
    func countInstances(of stringToFind: String) -> Int {
        assert(!stringToFind.isEmpty)
        var searchRange: Range<String.Index>?
        var count = 0
        while let foundRange = range(of: stringToFind, options: .diacriticInsensitive, range: searchRange) {
            searchRange = Range(uncheckedBounds: (lower: foundRange.upperBound, upper: endIndex))
            count += 1
        }
        return count
    }
}

let iboutletEx = Regex("@IBOutlet.*\\s(\\w+):.+!")
let beginPattern = "// Begin outlet asserts"
let endPattern = "// End outlet asserts"
let awakePattern = "super.awakeFromNib()"
let viewDidLoadPattern = "super.viewDidLoad()"

extension SourceEditorCommand {
    func assertOutlets() {
        if source.contentUTI as CFString != kUTTypeSwiftSource  {
            finish(error: CommandError.onlySwift)
            return
        }
        let cursor = (source.selections[0] as! XCSourceTextRange).start.line

        var outlets = [String]()
        var beginAsserts: Int?
        var endAsserts: Int?
        var awakeLine: Int?
        var viewDidLine: Int?
        var classStartLine = 0

        enumerateLines { (lineIndex, line, braceLevel, previousLevel, stop) in
            if previousLevel == 0 && braceLevel == 1 {
                classStartLine = lineIndex
            }

            if braceLevel == 1 || (previousLevel == 1 && braceLevel == 2) {
                if let matches = iboutletEx.matchGroups(line), let name = matches[1] {
                    outlets.append(name)
                }
            } else if braceLevel == 2 {
                if line.contains(beginPattern) {
                    beginAsserts = lineIndex
                } else if line.contains(endPattern) {
                    endAsserts = lineIndex + 1
                } else if line.contains(viewDidLoadPattern) {
                    viewDidLine = lineIndex + 1
                } else if line.contains(awakePattern) {
                    awakeLine = lineIndex + 1
                }
            } else if braceLevel == 0 && previousLevel == 1 {
                // end of scope
                if cursor > 0 && (classStartLine > cursor || lineIndex < cursor) {
                    // cursor not inside current class, cursor == 0 for no cursor position
                    beginAsserts = nil
                    endAsserts = nil
                    outlets = []
                    viewDidLine = nil
                    awakeLine = nil
                    return
                }

                if outlets.isEmpty {
                    if cursor == 0 {
                        return
                    }
                    stop = true
                    return
                }

                var asserts = assertions(outlets: outlets, prefix: indentationString(level: 2))

                if let beginAsserts = beginAsserts, let endAsserts = endAsserts, endAsserts > beginAsserts {
                    deleteLines(from: beginAsserts, to: endAsserts)
                    insert(asserts, at: beginAsserts, select: cursor == 0)
                    moveCursor(toLine: beginAsserts + asserts.count, column: 0)
                } else if let viewDidLine = viewDidLine {
                    asserts.insert("\n", at: 0)
                    asserts.append("\n")
                    insert(asserts, at: viewDidLine, select: cursor == 0)
                    moveCursor(toLine: viewDidLine + asserts.count, column: 0)
                } else if let awakeLine = awakeLine {
                    asserts.insert("\n", at: 0)
                    asserts.append("\n")
                    insert(asserts, at: awakeLine, select: cursor == 0)
                    moveCursor(toLine: awakeLine + asserts.count, column: 0)
                } else {
                    finish(error: CommandError.noVDLorAFN)
                }

                stop = true
            }
        }

        finish()
    }

    private func assertions(outlets: [String], prefix: String) -> [String] {
        var out = ["\(prefix)\(beginPattern)"]
        for outlet in outlets {
            out.append("\(prefix)assert(\(outlet) != nil, \"IBOutlet \(outlet) not connected\")")
        }
        out.append("\(prefix)\(endPattern)")
        return out
    }
}
