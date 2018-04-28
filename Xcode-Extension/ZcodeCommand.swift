//
//  ZcodeCommand.swift
//  ZCode
//
//  Created by Guy on 27/04/2018.
//  Copyright © 2018 Houzz. All rights reserved.
//

import Foundation

struct SourcePosition {
    let line: Int
    let column: Int

    var isZero: Bool {
        return self.line == 0 && self.column == 0
    }
}

struct CommandOptions: OptionSet {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let coding = CommandOptions(rawValue: 1)
    public static let none = CommandOptions(rawValue: 0)
    public static let copying = CommandOptions(rawValue: 1 << 1)
    public static let customInit = CommandOptions(rawValue: 1 << 2)
    public static let read = CommandOptions(rawValue: 1 << 3)
    public static let assert = CommandOptions(rawValue: 1 << 4)
    public static let cast = CommandOptions(rawValue: 1 << 5)
    public static let defaults = CommandOptions(rawValue: 1 << 6)
}


public enum CommandError: Int, Error {
    case onlySwift
    case unknown
    case noVDLorAFN
    case noDefaultsClass

    var localizedDescription: String {
        switch self {
        case .onlySwift:
            return "Only Swift files are supported"

        case .unknown:
            return "Unknwon Error"

        case .noVDLorAFN:
            return "Need super.viewDidLoad() for UIViewController subclass or super.awakeFromNib() for UIView subclass"

        case .noDefaultsClass:
            return "Didn't find any class inherting from UserDefaults"
        }
    }

    var error: NSError {
        return NSError(domain: "ZCode", code: rawValue + 100, userInfo: [NSLocalizedDescriptionKey: localizedDescription])
    }
}


protocol ZcodeCommand: class {
    var linePos: Int { get set }
    func selectLines(from: Int, count: Int)
    var cursorPosition: SourcePosition { get }
    func deleteLines(from: Int, to: Int)
    func insert(_ newlines: [String], at idx: Int, select: Bool)
    func indentationString(level: Int) -> String
    var lineCount: Int { get }
    func line(_ idx: Int) -> String
    func finish(error: CommandError?)
    func moveCursor(toLine line: Int, column: Int)
}


