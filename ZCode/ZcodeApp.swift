//
//  ZcodeApp.swift
//  ZCode
//
//  Created by Guy on 27/04/2018.
//  Copyright © 2018 Houzz. All rights reserved.
//

import Foundation

class LinesSource : ZcodeCommand {
    var linePos: Int = 0
    var source: [String]
    var completionHandler: ((Error?) -> Void)?
    var fileURL: URL

    var lineCount: Int {
        return source.count
    }

    func line(_ idx: Int) -> String {
        return source[idx]
    }

    init?(file: URL, completion: @escaping (Error?) -> Void) {
        fileURL = file
        guard let fileContent = try? String(contentsOf: file, encoding: .utf8) else {
            return nil
        }
        source = fileContent.components(separatedBy: "\n")
        completionHandler = completion
    }

    func selectLines(from: Int, count: Int) {
    }

    var cursorPosition: SourcePosition {
        return SourcePosition(line: 0, column: 0)
    }

    func deleteLines(from: Int, to: Int) {
        for i in (from ..< to).reversed() {
            source.remove(at: i)
            if linePos + 1 >= i {
                linePos -= 1
            }
        }
    }

    func insert(_ newlines: [String], at idx: Int, select: Bool = true) {
        var insertion = idx
        for line in newlines {
            source.insert(line, at: insertion)
            insertion += 1
            if linePos + 1 >= insertion {
                linePos += 1
            }
        }
    }

    func indentationString(level: Int) -> String {
        var cache = [Int:String]()
        if let s = cache[level] {
            return s
        }
        let prefix = String(repeating: " ", count: level * 4)
        cache[level] = prefix
        return prefix
    }

    func moveCursor(toLine line: Int, column: Int) {
    }

    func finish(error: CommandError?) {
        if completionHandler == nil {
            return
        }
        if let error = error {
            completionHandler?(error)
        } else {
            do {
                try source.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
                print("Wrote file")
                completionHandler?(nil)
            } catch {
                completionHandler?(NSError(domain: "Zcode", code: 300, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]))
            }
        }
        completionHandler = nil
    }
}
