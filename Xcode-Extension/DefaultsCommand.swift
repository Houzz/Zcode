//
//  DefaultsCommand.swift
//  ZCode
//
//  Created by Guy on 28/04/2018.
//  Copyright © 2018 Houzz. All rights reserved.
//

import Foundation

struct DefaultKey {
    public enum DefaultType {
        case string
        case int
        case bool
        case float
        case dict
        case stringArray
        case dictArray
        case date
        case url
        case any

        public init(string: String) {
            switch string {
            case "int":
                self = .int

            case "bool":
                self = .bool

            case "float":
                self = .float

            case "dict":
                self = .dict

            case "stringArray":
                self = .stringArray

            case "dictArray":
                self = .dictArray

            case "date":
                self = .date

            case "url":
                self = .url

            case "string":
                self = .string

            default:
                self = .any
            }
        }
    }
    public struct Option: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public init(string: String?) {
            guard let string = string else {
                self = .none
                return
            }
            var value: Int = 0
            for component in string.replacingOccurrences(of: " ", with: "").components(separatedBy: ",") {
                switch component {
                case ".api":
                    value |= Option.api.rawValue

                case ".write":
                    value |= Option.write.rawValue

                case ".nil":
                    value |= Option.nil.rawValue

                case ".objc":
                    value |= Option.objc.rawValue

                case ".manual":
                    value |= Option.manual.rawValue

                default:
                    break
                }
            }
            self.init(rawValue: value)
        }

        static public let api = Option(rawValue: 1)  /// default can come in api (metadata for houzz) response, see also null
        static public let none = Option(rawValue: 0)
        static public let write = Option(rawValue: 1 << 1) /// generate a write setter
        static public let `nil` = Option(rawValue: 1 << 2) /// for a value returned by the API, overwrite even if nil is returned
        static public let objc = Option(rawValue: 1 << 3) /// make accessors @objc
        static public let manual = Option(rawValue: 1 << 4) /// accessor is generated manually
    }
    /// Name of property
    public let name: String
    /// Type of property
    public let type: DefaultType
    /// Default value options
    public let options: Option
    /// If it has a default value, if none set
    public let `default`: Any?
    /// key name in api response
    public let key: String?

    public init(_ name: String, type: DefaultType, options: Option = .none, default value: Any? = nil, key: String? = nil) {
        self.name = name
        self.type = type
        self.options = options
        self.default = value
        self.key = key
    }
}


extension DefaultKey {
    var prefKey: String {
        if options.contains(.api) {
            return name[0].uppercased() + name[1...]
        }
        return name
    }
    var isOptional: Bool {
        switch type {
        case .bool, .int, .float:
            return false

        default:
            return self.default == nil
        }
    }
    var getStatement: String {
        switch type {
        case .string, .date, .dictArray, .dict, .stringArray:
            return "object(forKey: \"\(prefKey)\") as\(isOptional ? "?" : "!") \(type.stringValue)"

        case .bool:
            return "bool(forKey: \"\(prefKey)\")"

        case .float:
            return "float(forKey: \"\(prefKey)\")"

        case .int:
            return "integer(forKey: \"\(prefKey)\")"

        case .url:
            return "URL(string: object(forKey: \"\(prefKey)\") as? String ?? \"\")\(isOptional ? "" : "!")"

        default:
            return "object(forKey: \"\(prefKey)\")"
        }
    }
    var setStatement: String {
        switch type {
        case .url:
            return "set(newValue\(isOptional ? "?" : "").absoluteString, forKey: \"\(prefKey)\")"

        default:
            return "set(newValue, forKey: \"\(prefKey)\")"
        }
    }
}

extension DefaultKey.DefaultType {
    var stringValue: String {
        switch self {
        case .string:
            return "String"
        case .bool:
            return "Bool"
        case .int:
            return "Int"
        case .float:
            return "Float"
        case .date:
            return "Date"
        case .dict:
            return "[String: Any]"
        case .dictArray:
            return "[[String: Any]]"
        case .stringArray:
            return "[String]"
        case .url:
            return "URL"
        case .any:
            return "Any"
        }
    }
}


extension SourceZcodeCommand {
    public func makeDefaults() {
        let defKeyRegex = Regex("DefaultKey\\(\"(.*)\", *type: *.([a-zA-Z]+)(?:, options: *)?(?:\\[(.*?)\\])?")
        let classRegex = Regex("(class|struct) +([^ :]+)[ :]+ *UserDefaults(.*)\\{ *$", options: [.anchorsMatchLines])
        let endPattern = "// MARK: - Generated accessors"
        var className: String? = nil
        var markLine: Int? = nil
        var vars = [DefaultKey]()

        enumerateLines { (in_lineIndex, line, braceLevel, priorBraceLevel, stop) in
            switch priorBraceLevel {
            case 0:
                if let groups = classRegex.matchGroups(line), let name = groups[2] {
                    className = name
                } else if line.contains(endPattern) {
                    markLine = in_lineIndex
                }

            case 1:
                if let groups = defKeyRegex.matchGroups(line), let name = groups[1], let type = groups[2] {
                    let d = line.contains("default:") && !line.contains("default: nil") ? "x" : nil
                    vars.append(DefaultKey(name, type: DefaultKey.DefaultType(string: type), options: DefaultKey.Option(string: groups[3]), default: d, key: nil))
                }

            default:
                break
            }
        }

        guard let name = className else {
            finish(error: CommandError.noDefaultsClass)
            return
        }

        var output = [endPattern]
        if let mark = markLine {
        deleteLines(from: mark, to: source.lineCount)
        }
        output.append("extension \(name) {")
        for prop in vars {
            if prop.options.contains(.manual) {
                continue
            }
            let objc = prop.options.contains(.objc) ? "@objc " : ""
            output.append("\(indentationString(level: 1))\(objc)public var \(prop.name): \(prop.type.stringValue)\(prop.isOptional ? "?" : "") {")
            let isWritable = prop.options.contains(.write)
            if isWritable {
            output.append("\(indentationString(level: 2))get {")
            }
            output.append("\(indentationString(level: isWritable ? 3 : 2))return \(prop.getStatement)")
            if isWritable {
            output.append("\(indentationString(level: 2))}")
            }
            if isWritable {
                output.append("\(indentationString(level: 2))set {")
                output.append("\(indentationString(level: 3))\(prop.setStatement)")
                output.append("\(indentationString(level: 2))}")
            }
            output.append("\(indentationString(level: 1))}")
        }
        output.append("}")
        insert(output, at: source.lineCount)
        finish()
    }
}
