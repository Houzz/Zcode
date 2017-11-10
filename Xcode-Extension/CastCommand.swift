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

        output.append("")
        output.append("\(editor.indentationString(level: 2))// Add custom code after this comment")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
    }

    func createDictionaryRepresentation(lineIndex: Int, editor: SourceEditorCommand) {
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
        output.append("\(editor.indentationString(level: 2))return dict")
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
    }

    func createInitWithCoder(lineIndex: Int, editor: SourceEditorCommand) {
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
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
    }

    func createEncodeWithCoder(lineIndex: Int, editor: SourceEditorCommand) {
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

        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
    }

    func createCopy(lineIndex: Int, editor: SourceEditorCommand) {
        var output = [String]()
        output.append("\(editor.indentationString(level: 1))\(classAccess) func copy(with zone: NSZone? = nil) -> Any { // Generated")
        output.append("\(editor.indentationString(level: 2))return NSKeyedUnarchiver.unarchiveObject(with: NSKeyedArchiver.archivedData(withRootObject: self))!")
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
        var parseInfo: ParseInfo?
        let initRegex = Regex("init\\?\\(dictionary dict: *JSONDictionary\\) *\\{ *// *Generated")
        var initLines:(start:Int?,end:Int?)
        var readLines:(start:Int?,end:Int?, custom: [String]?, inRead: Bool, inCustom: Bool) = (start:nil, end:nil, custom:nil, inRead:false, inCustom: false)
        let readPattern = "func read(from dict: JSONDictionary) { // Generated"
        let startReadCustomPattern = "// Add custom code after this comment"
        var dicRepLines:(start:Int?,end:Int?)
        let dicRepPattern = "func dictionaryRepresentation() -> [String: Any] { // Generated"
        var initCoderLines:(start: Int?, end: Int?)
        var initCoderPattern = "init?(coder aDecoder: NSCoder) { // Generated"
        var encodeCoderLines:(start:Int?, end:Int?)
        var encodeCoderPattern = "func encode(with aCoder: NSCoder) { // Generated"
        var copyLines:(start:Int?, end: Int?)
        var copyPattern = "func copy(with zone: NSZone? = nil) -> Any { // Generated"
        
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
                            insert([""], at: lineIndex, select: false)
                            info.createInitWithDict(lineIndex: lineIndex + 1, editor: self)
                        }
                        if let start = readLines.start, let end = readLines.end {
                            deleteLines(from: start, to: end + 1)
                            info.createRead(lineIndex: start, customLines: readLines.custom, editor: self)
                        } else if command == .read {
                            insert([""], at: lineIndex, select: false)
                            info.createRead(lineIndex: lineIndex + 1, customLines: readLines.custom, editor: self)
                        }
                        if let start = dicRepLines.start, let end = dicRepLines.end {
                            deleteLines(from: start, to: end + 1)
                            info.createDictionaryRepresentation(lineIndex: start, editor: self)
                        } else if command == .cast {
                            insert([""], at: lineIndex, select: false)
                            info.createDictionaryRepresentation(lineIndex: lineIndex + 1, editor: self)
                        }
                        if let start = copyLines.start, let end = copyLines.end {
                            deleteLines(from: start, to: end + 1)
                            info.createCopy(lineIndex: start, editor: self)
                        } else if info.classInheritence!.contains("NSCopying") || command == .copy {
                            insert([""], at: lineIndex, select: false)
                            info.createCopy(lineIndex: lineIndex, editor: self)
                        }
                        if let start = initCoderLines.start, let end = initCoderLines.end {
                            deleteLines(from: start, to: end + 1)
                            info.createInitWithCoder(lineIndex: start, editor: self)
                        } else if info.classInheritence!.contains("NSCoding") || command == .copy || command == .nscoding {
                            insert([""], at: lineIndex, select: false)
                            info.createInitWithCoder(lineIndex: lineIndex, editor: self)
                        }
                        if let start = encodeCoderLines.start, let end = encodeCoderLines.end {
                            deleteLines(from: start, to: end + 1)
                            info.createEncodeWithCoder(lineIndex: start, editor: self)
                        } else if info.classInheritence!.contains("NSCoding") || command == .copy {
                            insert([""], at: lineIndex, select: false)
                            info.createEncodeWithCoder(lineIndex: lineIndex, editor: self)
                        }
                        parseInfo = nil
                    }
                } else if braceLevel == 1 {
                    if priorBraceLevel == 2 {
                        if initLines.start != nil && initLines.end == nil {
                            initLines.end = lineIndex
                        } else if readLines.inRead {
                            readLines.end = lineIndex
                            readLines.inRead = false
                            readLines.inCustom = false
                        } else if dicRepLines.start != nil && dicRepLines.end == nil {
                            dicRepLines.end = lineIndex
                        } else if copyLines.start != nil && copyLines.end == nil {
                            copyLines.end = lineIndex
                        } else if initCoderLines.start != nil && initCoderLines.end == nil {
                            initCoderLines.end = lineIndex
                        } else if encodeCoderLines.start != nil && encodeCoderLines.end == nil {
                            encodeCoderLines.end = lineIndex
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
                        } else if line.contains(dicRepPattern) {
                            dicRepLines.start = lineIndex
                        } else if line.contains(copyPattern) {
                            copyLines.start = lineIndex
                        } else if line.contains(initCoderPattern) {
                            initCoderLines.start = lineIndex
                        } else if line.contains(encodeCoderPattern) {
                            encodeCoderLines.start = lineIndex
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
