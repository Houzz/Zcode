//
//  File.swift
//  XCodeExtension
//
//  Created by Guy on 08/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation

let startReadCustomPattern = "// Add custom code after this comment"

extension String {
    func snakeCased() -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: self.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2").lowercased() 
    }

    func jsonKey(asIs: Bool) -> String {
        let correctCaseKey: String = trimmingCharacters(in: CharacterSet.whitespaces)
        if asIs {
            return correctCaseKey
        }
        switch Defaults.keyCase {
        case .none:
            return correctCaseKey

        case .upper:
            return "\(correctCaseKey[0].uppercased())\(correctCaseKey[1 ..< correctCaseKey.count])"

        case .snake:
            return correctCaseKey.snakeCased()
        }
    }
}

extension Bool {
    init?(onoff: String) {
        switch onoff.lowercased() {
        case "on":
            self = true

        case "off":
            self = false

        default:
            return nil
        }
    }
}


struct VarInfo {
    let name: String
    let type: String
    let defaultValue: String?
    let key: [String]
    var optional: Bool
    let isNullable: Bool
    let isLet: Bool
    let useCustomParse: Bool
    let skip: Bool
    let className: String

    init(name: String, isLet: Bool, type: String, defaultValue: String? = nil, asIsKey: Bool, key in_key: String? = nil, useCustom: Bool = false, skip: Bool = false, className: String) {
        self.name = name
        self.isLet = isLet
        self.skip = skip
        self.className = className
        useCustomParse = useCustom
        if type.hasSuffix("?") || type.hasSuffix("!") {
            self.isNullable = true
            self.type = type.trimmingCharacters(in: CharacterSet(charactersIn: "!?"))
            self.optional = type.hasSuffix("?")
        } else {
            self.type = type
            self.optional = false
            self.isNullable = false
        }

        self.key = (in_key ?? name).components(separatedBy: "??").map {
            $0.components(separatedBy: "/").map { $0.jsonKey(asIs: asIsKey) }.joined(separator:"/")
        }
        self.defaultValue = defaultValue
    }

    var encodeCall: String {
        get {
            var ret = ""
            var vv = name
            if optional {
                vv = "\(name)?"
            }

            ret += "\(vv).encode(with: aCoder, forKey: \"\(name)\")"

            return ret
        }
    }

    func decodeCall(editor: SourceEditorCommand) -> [String] {
        var v = [String]()
        v.append("\(editor.indentationString(level: 2))if let v = \(type).decode(with: aDecoder, fromKey:\"\(name)\") {")
        v.append("\(editor.indentationString(level: 3))\(name) = v")
        v.append("\(editor.indentationString(level: 2))}")

        if let def = defaultValue {
            v.append("\(v.removeLast()) else {")
            v.append("\(editor.indentationString(level: 3))\(name) = \(def)")
            v.append("\(editor.indentationString(level: 2))}")
        } else if optional {
            v.append("\(v.removeLast()) else {")
            v.append("\(editor.indentationString(level: 3))\(name) = nil")
            v.append("\(editor.indentationString(level: 2))}")
        } else {
            v.append("\(v.removeLast()) else {")
            v.append("\(editor.indentationString(level: 3))return nil")
            v.append("\(editor.indentationString(level: 2))}")
        }

        return v
    }

    func generateRead(nilMissing doNil: Bool, className: String, disableHouzzzLogging:Bool, editor: SourceEditorCommand) -> [String] {
        guard skip == false else {
            return []
        }
        var output = [String]()
        var assignments: [String]
        if useCustomParse {
            let caseName = "\(name[0].uppercased())\(name[1 ..< name.count])"
            assignments = [ "\(className).parse\(caseName)(from: dict)"]
        } else {
            assignments = key.map { "dict.value(for: \"\($0)\")" }
        }
        if doNil {
            if let defaultValue = defaultValue {
                assignments.append("\(defaultValue)")
            }
        }
        let assignExpr = assignments.joined(separator: " ?? ")
        if (optional || isNullable || defaultValue != nil) && doNil {
            if type == "String" && Defaults.nilEmptyStrings {
                output.append("\(editor.indentationString(level: 2))if let v:\(type) = \(assignExpr), !v.isEmpty {")
                output.append("\(editor.indentationString(level: 3))\(name) = v")
                output.append("\(editor.indentationString(level: 2))} else {")
                
                output.append("\(editor.indentationString(level: 3))\(name) = nil")
                output.append("\(editor.indentationString(level: 2))}")
            } else {
            output.append("\(editor.indentationString(level: 2))\(name) = \(assignExpr)")
            }
        } else {
            if type == "String" && Defaults.nilEmptyStrings {
                output.append("\(editor.indentationString(level: 2))if let v:\(type) = \(assignExpr), !v.isEmpty {")
            } else {
            output.append("\(editor.indentationString(level: 2))if let v:\(type) = \(assignExpr) {")
            }
            output.append("\(editor.indentationString(level: 3))\(name) = v")
            output.append("\(editor.indentationString(level: 2))}")
            if doNil {
                output.removeLast()
                output.append("\(editor.indentationString(level: 2))} else {")
                if Defaults.useLogger && !disableHouzzzLogging {
                    output.append("\(editor.indentationString(level: 3))LogError(\"Error: \(className).\(name) failed init\")")
                }
                output.append("\(editor.indentationString(level: 3))return nil")
                output.append("\(editor.indentationString(level: 2))}")
            }
        }
        return output
    }

    func getInitParam() -> String? {
        if skip {
            return nil
        }
        let optPart = optional || self.isNullable ? "?" : ""
        let defaultValue = self.defaultValue ?? (self.optional  ? "nil" : nil)
        return "\(name): \(type)\(optPart)" + (defaultValue.map { " = " + $0 } ?? "")
    }

    func getInitAssign() -> String {
        return "self.\(name) = \(name)"
    }
}

private enum Function {
    case initWithCoder
    case initDictionary
    case dictionaryRepresentation
    case copy
    case read
    case encode
    case customInit
}

private class FunctionInfo {
    var start: Int? = nil
    var end: Int? = nil
    var expression: String
    var inside: Bool = false
    var inBlock: Bool = false
    var custom: [String]? = nil
    let create: (Int, ParseInfo, [String]?, SourceEditorCommand) -> Int
    fileprivate let condition: (Command, ParseInfo) -> Bool

    init(expression: String, condition: @escaping (Command, ParseInfo) -> Bool, create: @escaping (Int, ParseInfo, [String]?, SourceEditorCommand) -> Int) {
        self.expression = expression
        self.condition = condition
        self.create = create
    }
}



private class ParseInfo {
    var classInheritence: [String]?
    var className: String?
    var isStruct = false
    var classAccess = ""
    var isObjc = false
    var disableHouzzzLogging = false
    var superTag: String? = nil
    var variables = [VarInfo]()

    func createInitWithDict(lineIndex: Int, editor: SourceEditorCommand) -> Int {
        var output = [String]()
        var override = ""
        if classInheritence == nil {
            classInheritence = [String]()
        }
        if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
            override = "override"
        }

        // init
        let reqStr = isStruct ? "" : "required"
        let initAccess =  classAccess == "open" ? "public" : classAccess

        output.append("\(editor.indentationString(level: 1))\(reqStr) \(initAccess) init?(dictionary dict: JSONDictionary) { // Generated")

        for variable in variables {
            if variable.skip {
                continue
            }
            output += variable.generateRead(nilMissing: true, className: className!, disableHouzzzLogging:disableHouzzzLogging, editor: editor)
        }


        if !override.isEmpty {
            if let superTag = superTag {
                output.append("\(editor.indentationString(level: 2))guard let superDict = dict.any(forKeyPath: \"\(superTag)\") as? JSONDictionary else {")
                output.append("\(editor.indentationString(level: 3))return nil")
                output.append("\(editor.indentationString(level: 2))}")
                output.append("\(editor.indentationString(level: 2))super.init(dictionary: superDict)")
            } else {
                output.append("\(editor.indentationString(level: 2))super.init(dictionary: dict)")
            }
        } else if classInheritence!.contains("DictionaryConvertible") && classInheritence![0] != "DictionaryConvertible" && !isStruct && override.isEmpty {
            output.append("\(editor.indentationString(level: 2))super.init()")
        }
        if override == "" {
            output.append("\(editor.indentationString(level: 2))if !awake(with: dict) {")
            output.append("\(editor.indentationString(level: 3))return nil")
            output.append("\(editor.indentationString(level: 2))}")
        }
        output.append("\(editor.indentationString(level: 1))}")

        editor.insert(output, at: lineIndex, select: true)
        return output.count
    }

    func createRead(lineIndex: Int, customLines:[String]?, editor: SourceEditorCommand) -> Int {
        var output = [String]()
        var override = ""
        if classInheritence == nil {
            classInheritence = [String]()
        }
        if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
            override = "override"
        }
        output.append("\(editor.indentationString(level: 1))\(override) \(classAccess) func read(from dict: JSONDictionary) { // Generated")

        for variable in variables {
            if !variable.isLet {
                output += variable.generateRead(nilMissing: false, className: className!, disableHouzzzLogging:disableHouzzzLogging, editor: editor)
            }
        }

        if !override.isEmpty {
            if let superTag = superTag {
                output.append("\(editor.indentationString(level: 2))guard let superDict = dict.any(forKeyPath: \"\(superTag)\") as? JSONDictionary else {")
                output.append("\(editor.indentationString(level: 3))return")
                output.append("\(editor.indentationString(level: 2))}")
                output.append("\(editor.indentationString(level: 2))super.read(from: superDict)")
            } else {
                output.append("\(editor.indentationString(level: 2))super.read(from: dict)")
            }
        }

        output.append("")
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }

    func createDictionaryRepresentation(lineIndex: Int, customLines: [String]?, editor: SourceEditorCommand) -> Int {
        var output = [String]()
        var override = ""
        if classInheritence == nil {
            classInheritence = [String]()
        }
        if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
            override = "override"
        }
        output.append("\(editor.indentationString(level: 1))\(isObjc ? "@objc" : "") \(override) \(classAccess) func dictionaryRepresentation() -> [String: Any] { // Generated")
        if override.isEmpty {
            output.append("\(editor.indentationString(level: 2))var dict = [String: Any]()")
        } else {
            if let superTag = superTag {
                output.append("\(editor.indentationString(level: 2))var dict:[String:Any] = [\"\(superTag)\": super.dictionaryRepresentation()]")
            } else {
                output.append("\(editor.indentationString(level: 2))var dict = super.dictionaryRepresentation()")
            }
        }

        var level = 2
        for variable in variables {
            if variable.skip {
                continue;
            }
            let optStr = variable.optional ? "?" : ""
            let keys = variable.key.first!.components(separatedBy: "/")
            for (idx, key) in keys.enumerated() {
                let dName = (idx == 0) ? "dict" : "dict\(idx)"
                if idx == keys.count - 1 {
                    output.append("\(editor.indentationString(level: level))if let x = \(variable.name)\(optStr).jsonValue {")
                    output.append("\(editor.indentationString(level: level + 1))\(dName)[\"\(key)\"] = x")
                    output.append("\(editor.indentationString(level: level))}")

                    for idx2 in(0 ..< idx).reversed() {
                        let idx3 = idx2 + 1
                        let dName = (idx2 == 0) ? "dict" : "dict\(idx2)"
                        let prevName = "dict\(idx3)"
                        output.append("\(editor.indentationString(level: level))\(dName)[\"\(keys[idx2])\"] = \(prevName)")
                        level -= 1
                        output.append("\(editor.indentationString(level: level))}")
                    }
                } else {
                    let nidx = idx + 1
                    let nextName =  "dict\(nidx)"
                    output.append("\(editor.indentationString(level: level))do {")
                    level += 1
                    output.append("\(editor.indentationString(level: level))var \(nextName) = \(dName)[\"\(key)\"] as? [String: Any] ?? [String: Any]()")
                }
            }
        }
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        } else {
            output.append("\(editor.indentationString(level: 2))return dict")
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }

    func createInitWithCoder(lineIndex: Int, customLines: [String]?, editor: SourceEditorCommand) -> Int {
        let codingOverride = !classInheritence!.contains("NSCoding")
        var output = [String]()
        let initAccess =  classAccess == "open" ? "public" : classAccess

        output.append("\(editor.indentationString(level: 1))required \(initAccess) init?(coder aDecoder: NSCoder) { // Generated")

        for variable in variables {
            output += variable.decodeCall(editor: editor)
        }

        if codingOverride {
            output.append("\(editor.indentationString(level: 2))super.init(coder:aDecoder)")
        }
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }

    func createEncodeWithCoder(lineIndex: Int, customLines: [String]?, editor: SourceEditorCommand) -> Int {
        var output = [String]()
        let codingOverride = !classInheritence!.contains("NSCoding")
        let codingOverrideString = codingOverride ? "override" : ""
        output.append("\(editor.indentationString(level: 1))\(classAccess) \(codingOverrideString) func encode(with aCoder: NSCoder) { // Generated")
        if codingOverride {
            output.append("\(editor.indentationString(level: 2))super.encode(with: aCoder)")
        }

        for variable in variables {
            output.append("\(editor.indentationString(level: 2))\(variable.encodeCall)")
        }

        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }

    func createCopy(lineIndex: Int, customLines: [String]?, editor: SourceEditorCommand) -> Int {
        var output = [String]()
        output.append("\(editor.indentationString(level: 1))\(classAccess) func copy(with zone: NSZone? = nil) -> Any { // Generated")
        output.append("\(editor.indentationString(level: 2))let aCopy = NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: self))!")
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        } else {
            output.append("\(editor.indentationString(level: 2))return aCopy")
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }

    func createCustomInit(lineIndex: Int, customLines: [String]?, editor: SourceEditorCommand) -> Int {
        var output = [String]()
        let initAccess =  classAccess == "open" ? "public" : classAccess
        let params = variables.compactMap { return $0.getInitParam() }.joined(separator: ", ")
        output.append("\(editor.indentationString(level: 1))\(initAccess) init(\(params)) { // Generated Init")
        for variable in variables {
            if variable.skip == false {
                output.append("\(editor.indentationString(level: 2))\(variable.getInitAssign())")
            }
        }
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }
}


extension SourceEditorCommand {

    func cast(command: Command) {
        if source.contentUTI as CFString != kUTTypeSwiftSource  {
            finish(error: CommandError.onlySwift)
            return
        }
        
        let classRegex = Regex("(class|struct) +([^ :]+)[ :]+(.*)\\{ *$", options: [.anchorsMatchLines])
        let varRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *\\{* *(?://! *(?:= *([^ ]+))? *(?:(v?)\"([^\"]+)\")?)?")
        let customVarRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *//! *custom")
        let dictRegex = Regex("(var|let) +([^: ]+?) *: *(\\[.*?:.*?\\][!?]) *\\{* *(?://! *(?:= *([^ ]+))? (v?)\"([^ ]+)\")?")
        let customDictRegex = Regex("(var|let) +([^: ]+?) *: *(\\[.*?:.*?\\][!?]) *//! *custom")
        let skipVarRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *//! *(?:= *([^ ]+))? *ignore json")
        let ignoreRegex = Regex("(.*)//! *ignore", options: [.caseInsensitive])
        let accessRegex = Regex("(public|private|internal|open)")
        let disableLogging = Regex("//! *nolog")
        let superTagRegex = Regex("//! +super +\"([^\"]+)\"")
        var parseInfo: ParseInfo?
        var startClassLine = 0
        let caseCommand = Regex("//! *zcode: +case +([a-z]+)", options: [.caseInsensitive])
        let logCommand = Regex("//! *zcode: +logger +(on|off|true|false)", options: [.caseInsensitive])
        let nilCommand = Regex("//! *zcode: +emptyisnil +(on|off|true|false)", options: [.caseInsensitive])

        var functions = [Function: FunctionInfo]()
        functions[.copy] = FunctionInfo(expression: "func copy(with zone: NSZone? = nil) -> Any { // Generated", condition: { (command, info) in
            (info.classInheritence!.contains("NSCopying") && command == .cast) || command == .copy
        }, create: { (line, info, custom, editor) -> Int in
            info.createCopy(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.encode] = FunctionInfo(expression: "func encode(with aCoder: NSCoder) { // Generated", condition: { (command, info) in
            (info.classInheritence!.contains("NSCoding") && command == .cast) || command.isOneOf(.copy, .nscoding)
        }, create: { (line, info, custom, editor) in
            info.createEncodeWithCoder(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.initWithCoder] = FunctionInfo(expression: "init?(coder aDecoder: NSCoder) { // Generated", condition: { (command, info) in
            (info.classInheritence!.contains("NSCoding") && command == .cast) || command.isOneOf(.copy, .nscoding)
        }, create: { (line, info, custom, editor) in
            info.createInitWithCoder(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.dictionaryRepresentation] = FunctionInfo(expression: "func dictionaryRepresentation() -> [String: Any] { // Generated", condition: { (command, info) in
            command == .cast
        }, create: { (line, info, custom, editor) in
            info.createDictionaryRepresentation(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.read] = FunctionInfo(expression: "func read(from dict: JSONDictionary) { // Generated", condition: { (command, info) in
            command == .read
        }, create: { (line, info, custom, editor) in
            info.createRead(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.initDictionary] = FunctionInfo(expression: "init?(dictionary dict: JSONDictionary) { // Generated", condition: { (command, info) in
            command == .cast
        }, create: { (line, info, _, editor) in
            info.createInitWithDict(lineIndex: line, editor: editor)
        })
        functions[.customInit] = FunctionInfo(expression: "// Generated Init", condition: { (command, _) -> Bool in
            command == .customInit
        }, create: { (line, info, custom, editor) in
            info.createCustomInit(lineIndex: line, customLines: custom, editor: editor)
        })
        
        enumerateLines { (in_lineIndex, line, braceLevel, priorBraceLevel, stop) in
            var lineIndex = in_lineIndex
            if braceLevel > 1 {
                for (_, info) in functions {
                    if info.inBlock {
                        if info.custom == nil {
                            info.custom = [line]
                        } else {
                            info.custom!.append(line)
                        }
                        return
                    }
                }
            } else if braceLevel == 0 {
                if let matches: [String?] = caseCommand.matchGroups(line), let type = CaseType(rawValue: matches[1]?.lowercased() ?? "") {
                    Defaults.override(.keyCase, value: type)
                } else if let matches: [String?] = logCommand.matchGroups(line), let v = Bool(onoff: matches[1] ?? "") {
                    Defaults.override(.useLogger, value: v)
                } else if let matches: [String?] = nilCommand.matchGroups(line), let v = Bool(onoff: matches[1] ?? "") {
                    Defaults.override(.nilStrings, value: v)
              }
            }
            
            if let info = parseInfo {
                if braceLevel == 0 {
                    if priorBraceLevel == 1 {
                        if lineIndex >= cursorPosition.line && cursorPosition.line >= startClassLine {
                            for (key, value) in functions {
                                if let start = value.start, let end = value.end {
                                    deleteLines(from: start, to: end + 1)
                                    if lineIndex > start {
                                        lineIndex -= min(end, lineIndex) - start + 1
                                    }
                                    lineIndex += value.create(start, info, value.custom, self)
                                } else if value.condition(command, info) {
                                    insert([""], at: lineIndex, select: false)
                                    _ = value.create(lineIndex + 1, info, value.custom, self)
                                }
                                functions[key]?.start = nil
                                functions[key]?.end = nil
                                functions[key]?.custom = nil
                            }
                            parseInfo = nil
                            stop = true
                        } else {
                            for (key, _) in functions {
                                functions[key]?.start = nil
                                functions[key]?.end = nil
                                functions[key]?.custom = nil
                            }
                            parseInfo = nil
                        }
                    }
                } else if priorBraceLevel == 2 && braceLevel == 1 {
                        for (_,info) in functions {
                            if info.inside {
                                info.end = lineIndex
                                info.inBlock = false
                                info.inside = false
                                break
                            }
                        }
                } else if priorBraceLevel == 1 {
                    if ignoreRegex.match(line) && !skipVarRegex.match(line) {
                        return // ignore these
                    } else if disableLogging.match(line) {
                        info.disableHouzzzLogging = true
                        return
                    } else if let matches: [String?] = skipVarRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: true, key: nil, useCustom: false, skip: true, className: info.className!))
                    } else if let matches: [String?] = customDictRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: nil, asIsKey: false, key: nil, useCustom: true, className: info.className!))
                    } else if let matches: [String?] = dictRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: false, className: info.className!))
                   } else if let matches: [String?] = customVarRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: nil, asIsKey: false, key: nil, useCustom: true, className: info.className!))
                   } else if let matches: [String?] = varRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: false, className: info.className!))
                    } else if let matches: [String?] = superTagRegex.matchGroups(line) {
                        if let str = matches[1] {
                            info.superTag = str
                        }
                    }
                } else if braceLevel == 2 {
                    if priorBraceLevel == 1 {
                        for (_,info) in functions {
                            if line.contains(info.expression) {
                                info.start = lineIndex
                                info.inside = true
                            }
                        }
                        return
                    }
                    for (_,info) in functions {
                        if info.inside && line.contains(startReadCustomPattern) {
                            info.inBlock = true
                            break
                        }
                    }
                }
            } else if braceLevel == 1 && priorBraceLevel == 0, let matches = classRegex.matchGroups(line) {
                parseInfo = ParseInfo()
                startClassLine = lineIndex
                parseInfo?.classInheritence = matches[3]?.replacingOccurrences(of: " ", with: "").components(separatedBy: ",")
                parseInfo?.className = matches[2]
                parseInfo?.isStruct = (matches[1] == "struct")
                parseInfo?.isObjc = line.contains("@objc")
                if let matches: [String?] = accessRegex.matchGroups(line) {
                    parseInfo?.classAccess = matches[1] ?? ""
                } else {
                    parseInfo?.classAccess = ""
                }
            }
        }
        
        finish()
    }


}
