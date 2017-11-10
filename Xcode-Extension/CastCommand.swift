//
//  File.swift
//  XCodeExtension
//
//  Created by Guy on 08/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation


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
            return $0.components(separatedBy: "/").map({
                let correctCaseKey: String = $0.trimmingCharacters(in: CharacterSet.whitespaces)
                if Defaults.upperCase && !asIsKey {
                    return "\(correctCaseKey[0].uppercased())\(correctCaseKey[1 ..< correctCaseKey.count])"
                }
                return correctCaseKey
            }).joined(separator:"/")
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

    var decodeCall: String {
        get {

            var v: String
            v = "if let v = \(type).decode(with: aDecoder, fromKey:\"\(name)\") {"
            v += "\n\t\t\t\(name) = v"
            v += "\n\t\t}"

            if let def = defaultValue {
                v += " else { \(name) = \(def) }"
            } else if optional {
                v += " else { \(name) = nil }"
            } else {
                v += " else { return nil }"
            }

            return v
        }
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
            output.append("\(editor.indentationString(level: 2))\(name) = \(assignExpr)")
        } else {
            output.append("\(editor.indentationString(level: 2))if let v:\(type) = \(assignExpr) {")
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
        return "\t\tself.\(name) = \(name)"
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

    func createInitWithDict(lineIndex: Int, editor: SourceEditorCommand) {
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
    }

    func createRead(lineIndex: Int, customLines:[String]?, editor: SourceEditorCommand) {
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

        output.append("\n")
        output.append("\(editor.indentationString(level: 2))// Add custom code after this comment")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
    }
}


extension SourceEditorCommand {

    func cast(command: Command) {
        if source.contentUTI as CFString != kUTTypeSwiftSource  {
            finish(error: CommandError.onlySwift)
            return
        }
        
        var priorBraceLevel = 0
        let classRegex = Regex("(class|struct) +([^ :]+)[ :]+(.*)\\{ *$", options: [.anchorsMatchLines])
        let varRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *(?://! *(?:= *([^ ]+))? *(v?)\"([^\"]+)\")?(?://! *(custom))?")
        let skipVarRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *//! *(?:= *([^ ]+))? *ignore json")
        let dictRegex = Regex("(var|let) +([^: ]+?) *: *(\\[.*?:.*?\\][!?]) *(?://! *(v?)\"([^ ]+)\")?(?://! *(?:= *([^ ]+))? *(custom))?")
        let ignoreRegex = Regex("(.*)//! *ignore", options: [.caseInsensitive])
        let enumRegex = Regex("enum ([^ :]+)[ :]+([^ ]+)")
        let accessRegex = Regex("(public|private|internal|open)")
        var braceLevel = 0
        var importRegex = Regex("import +([^ ]+)")
        var inImportBlock = false
        var commentRegex = Regex("^ *//[^!].*$")
        let disableLogging = Regex("//! *nolog")
        let superTagRegex = Regex("//! +super +\"([^\"]+)\"")
        let initRegex = Regex("init\\?\\(dictionary dict: *JSONDictionary\\) *\\{ *// *Generated")
        var parseInfo: ParseInfo?
        var initLines:(start:Int?,end:Int?)
        var readLines:(start:Int?,end:Int?, custom: [String]?, inRead: Bool, inCustom: Bool) = (start:nil, end:nil, custom:nil, inRead:false, inCustom: false)
        let readPattern = "func read(from dict: JSONDictionary) { // Generated"
        let startReadCustomPattern = "// Add custom code after this comment"
        
        enumerateLines { (lineIndex, line, braceLevel, stop) in
            defer {
                priorBraceLevel = braceLevel
            }

            if braceLevel > 1 && readLines.inCustom {
                if readLines.custom == nil {
                    readLines.custom = [line]
                } else {
                    readLines.custom!.append(line)
                }
                return
            }
            
            if let info = parseInfo {
                if braceLevel == 0 {
                    if priorBraceLevel == 1 {
                        if let start = initLines.start, let end = initLines.end {
                            deleteLines(from: start, to: end + 1)
                            info.createInitWithDict(lineIndex: start, editor: self)
                        } else if command == .cast {
                            insert(["\n"], at: lineIndex, select: false)
                            info.createInitWithDict(lineIndex: lineIndex + 1, editor: self)
                        }
                        if let start = readLines.start, let end = readLines.end {
                            deleteLines(from: start, to: end + 1)
                            info.createRead(lineIndex: start, customLines: readLines.custom, editor: self)
                        } else if command == .read {
                            insert(["\n"], at: lineIndex, select: false)
                            info.createRead(lineIndex: lineIndex + 1, customLines: readLines.custom, editor: self)
                        }
                        parseInfo = nil
                    }
                } else if braceLevel == 1 {
                    if priorBraceLevel == 2 {
                        if initLines.start != nil && initLines.end == nil {
                            initLines.end = lineIndex
                        }
                        if readLines.inRead {
                            readLines.end = lineIndex
                            readLines.inRead = false
                            readLines.inCustom = false
                        }
                    }
                    if ignoreRegex.match(line) && !skipVarRegex.match(line) {
                        return // ignore these
                    } else if disableLogging.match(line) {
                        info.disableHouzzzLogging = true
                        return
                    } else if let matches: [String?] = skipVarRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: true, key: nil, useCustom: false, skip: true, className: info.className!))
                    } else if let matches: [String?] = dictRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: matches[7] != nil, className: info.className!))
                    } else if let matches: [String?] = varRegex.matchGroups(line) {
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: matches[7] != nil, className: info.className!))
                    } else if let matches: [String?] = superTagRegex.matchGroups(line) {
                        if let str = matches[1] {
                            info.superTag = str
                        }
                    }
                } else if braceLevel == 2 {
                    if priorBraceLevel == 1 {
                        if initRegex.match(line) {
                            initLines.start = lineIndex
                        } else if line.contains(readPattern) {
                            readLines.inRead = true
                            readLines.start = lineIndex
                        }
                        return
                    }
                    if readLines.inRead && line.contains(startReadCustomPattern) {
                        readLines.inCustom = true
                    }
                }
            } else if braceLevel == 1 && priorBraceLevel == 0, let matches = classRegex.matchGroups(line) {
                parseInfo = ParseInfo()
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
