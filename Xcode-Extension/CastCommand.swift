//
//  File.swift
//  XCodeExtension
//
//  Created by Guy on 08/11/2017.
//  Copyright © 2017 Houzz. All rights reserved.
//

import Foundation
import CommonCrypto
let startReadCustomPattern = "// Add custom code after this comment"

extension String {
    func snakeCased() -> String {
        let pattern = "([a-z0-9])([A-Z])"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: self.count)
        return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2").lowercased() 
    }

    func jsonKey(asIs: Bool) -> String {
        let trimmedKey: String = trimmingCharacters(in: CharacterSet.whitespaces)
        if asIs {
            return trimmedKey
        }
        switch Defaults.keyCase {
        case .none:
            return trimmedKey

        case .upper:
            return "\(trimmedKey[0].uppercased())\(trimmedKey[1 ..< trimmedKey.count])"

        case .snake:
            return trimmedKey.snakeCased()

        case .screamingSnake:
            return trimmedKey.snakeCased().uppercased()
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

    fileprivate var encodeCall: String {
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

    fileprivate func decodeCall(editor: SourceZcodeCommand) -> [String] {
        var v = [String]()
        v.append("\(editor.indentationString(level: 2))if let v = \(type).decode(with: aDecoder, fromKey: \"\(name)\") {")
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

    fileprivate func generateRead(nilMissing doNil: Bool, className: String, disableHouzzzLogging:Bool, editor: SourceZcodeCommand) -> [String] {
        guard skip == false else {
            return []
        }
        var output = [String]()
        var assignments: [String]
        if useCustomParse {
            let caseName = "\(name[0].uppercased())\(name[1 ..< name.count])"
            assignments = [ "\(className).parse\(caseName)(from: dict)"]
        } else {
            assignments = key.map {
                if type == "String" && Defaults.nilEmptyStrings {
                    return "nilEmpty(dict.value(for: \"\($0)\"))"
                } else {
                    return "dict.value(for: \"\($0)\")"
                }
            }
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
            output.append("\(editor.indentationString(level: 2))if let v: \(type) = \(assignExpr) {")
            output.append("\(editor.indentationString(level: 3))\(name) = v")
            output.append("\(editor.indentationString(level: 2))}")
            if doNil {
                output.removeLast()
                output.append("\(editor.indentationString(level: 2))} else {")
                if Defaults.useLogger && !disableHouzzzLogging {
                    output.append("\(editor.indentationString(level: 3))LogError(\"Error: \(className).\(name) failed init\")")
                    output.append("\(editor.indentationString(level: 3))assert(false, \"Please open API ticket if needed\")")
                }
                output.append("\(editor.indentationString(level: 3))return nil")
                output.append("\(editor.indentationString(level: 2))}")
            }
        }
        return output
    }

    fileprivate func getInitParam() -> String? {
        if skip {
            return nil
        }
        let optPart = optional || self.isNullable ? "?" : ""
        let defaultValue = self.defaultValue ?? (self.optional  ? "nil" : nil)
        return "\(name): \(type)\(optPart)" + (defaultValue.map { " = " + $0 } ?? "")
    }

    fileprivate func getInitAssign() -> String {
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
    case multipart
}

class FunctionInfo {
    var start: Int? = nil
    var end: Int? = nil
    var expression: String
    var inside: Bool = false
    var inBlock: Bool = false
    var custom: [String]? = nil
    let create: (Int, ParseInfo, [String]?, SourceZcodeCommand) -> Int
    fileprivate let condition: (CommandOptions, ParseInfo) -> Bool

    init(expression: String, condition: @escaping (CommandOptions, ParseInfo) -> Bool, create: @escaping (Int, ParseInfo, [String]?, SourceZcodeCommand) -> Int) {
        self.expression = expression
        self.condition = condition
        self.create = create
    }
}



class ParseInfo {
    var classInheritence: [String]?
    var className: String?
    var isStruct = false
    var classAccess = ""
    var isObjc = false
    var disableHouzzzLogging = false
    var superTag: String? = nil
    var variables = [VarInfo]()

    fileprivate func createInitWithDict(lineIndex: Int, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        var override = ""
        if classInheritence == nil {
            classInheritence = [String]()
        }
        if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
            override = "override"
        }

        // init
        var l = [String]()
        if classAccess == "open" {
            l.append("public")
        } else if !classAccess.isEmpty {
            l.append(classAccess)
        }
        if !isStruct {
            l.append("required")
        }

        l.append("init?(dictionary dict: JSONDictionary) { // Generated")

        output.append("\(editor.indentationString(level: 1))\(l.joined(separator: " "))")

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

    fileprivate func createRead(lineIndex: Int, customLines:[String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        var override = ""
        if classInheritence == nil {
            classInheritence = [String]()
        }
        if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
            override = "override "
        }
        output.append("\(editor.indentationString(level: 1))\(override)\(classAccess.isEmpty ? "" : "\(classAccess) ")func read(from dict: JSONDictionary) { // Generated")

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

    fileprivate func createDictionaryRepresentation(lineIndex: Int, customLines: [String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        var subDicts = [String]()
        var override = ""
        var contentFor = [String: (String, Int)]()
        if classInheritence == nil {
            classInheritence = [String]()
        }
        if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
            override = "override "
        }
        output.append("\(editor.indentationString(level: 1))\(isObjc ? "@objc " : "")\(override)\(classAccess.isEmpty ? "" : "\(classAccess) ")func dictionaryRepresentation() -> [String: Any] { // Generated")
        if override.isEmpty {
            output.append("\(editor.indentationString(level: 2))var dict = [String: Any]()")
        } else {
            if let superTag = superTag {
                output.append("\(editor.indentationString(level: 2))var dict:[String:Any] = [\"\(superTag)\": super.dictionaryRepresentation()]")
            } else {
                output.append("\(editor.indentationString(level: 2))var dict = super.dictionaryRepresentation()")
            }
        }

        for variable in variables {
            if variable.skip {
                continue;
            }
            let optStr = variable.optional ? "?" : ""
            let keys = variable.key.first!.components(separatedBy: "/")
            var sameHeirarchy = true
            for (idx, key) in keys.enumerated() {
                let dName = (idx == 0) ? "dict" : "dict\(idx)"
                if idx == keys.count - 1 {
                    output.append("\(editor.indentationString(level: 2))\(dName)[\"\(key)\"] = \(variable.name)\(optStr).jsonValue")

                    for idx2 in (0 ..< idx).reversed() {
                        let idx3 = idx2 + 1
                        let dName = (idx2 == 0) ? "dict" : "dict\(idx2)"
                        let prevName = "dict\(idx3)"
                        let lhs = "\(dName)[\"\(keys[idx2])\"]"
                        if let c = contentFor[lhs], c.0 == prevName {
                            output.remove(at: c.1)
                            let before = contentFor
                            for (key,value) in before {
                                if value.1 > c.1 {
                                    contentFor[key] = (value.0, value.1 - 1)
                                }
                            }
                        }
                        contentFor[lhs] = (prevName, output.count)
                        output.append("\(editor.indentationString(level: 2))\(lhs) = \(prevName)")
                    }
                } else {
                    let nidx = idx + 1
                    let nextName = "dict\(nidx)"
                    if idx < subDicts.count && sameHeirarchy {
                        if key == subDicts[idx] {
                            continue
                        } else {
                            sameHeirarchy = false
                        }
                    }
                    output.append("\(editor.indentationString(level: 2))\(nidx > subDicts.count ? "var " : "")\(nextName) = \(dName)[\"\(key)\"] as? [String: Any] ?? [String: Any]()")
                }
            }
            if keys.count > 1 {
                for i in 0 ..< keys.count - 1 {
                    if i < subDicts.count {
                        subDicts[i] = keys[i]
                    } else {
                        subDicts.append(keys[i])
                    }
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
    
    fileprivate func createMultipartDictionaryRepresentation(lineIndex: Int, customLines: [String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        var subDicts = [String]()
        var override = ""
        var contentFor = [String: (String, Int)]()
        if classInheritence == nil {
            classInheritence = [String]()
        }
        if !classInheritence!.contains("DictionaryConvertible") && !isStruct {
            override = "override "
        }
        output.append("\(editor.indentationString(level: 1))\(isObjc ? "@objc " : "")\(override)\(classAccess.isEmpty ? "" : "\(classAccess) ")func multipartDictionaryRepresentation() -> [String: Any] { // Generated")
        if override.isEmpty {
            output.append("\(editor.indentationString(level: 2))var dict = [String: Any]()")
        } else {
            if let superTag = superTag {
                output.append("\(editor.indentationString(level: 2))var dict:[String:Any] = [\"\(superTag)\": super.multipartDictionaryRepresentation()]")
            } else {
                output.append("\(editor.indentationString(level: 2))var dict = super.multipartDictionaryRepresentation()")
            }
        }
        
        for variable in variables {
            if variable.skip {
                continue;
            }
            let optStr = variable.optional ? "?" : ""
            let keys = variable.key.first!.components(separatedBy: "/")
            var sameHeirarchy = true
            for (idx, key) in keys.enumerated() {
                let dName = (idx == 0) ? "dict" : "dict\(idx)"
                if idx == keys.count - 1 {
                    output.append("\(editor.indentationString(level: 2))\(dName)[\"\(className!.lowercased())[\(key)]\"] = \(variable.name)\(optStr).jsonValue")
                    
                    for idx2 in (0 ..< idx).reversed() {
                        let idx3 = idx2 + 1
                        let dName = (idx2 == 0) ? "dict" : "dict\(idx2)"
                        let prevName = "dict\(idx3)"
                        let lhs = "\(dName)[\"\(keys[idx2])\"]"
                        if let c = contentFor[lhs], c.0 == prevName {
                            output.remove(at: c.1)
                            let before = contentFor
                            for (key,value) in before {
                                if value.1 > c.1 {
                                    contentFor[key] = (value.0, value.1 - 1)
                                }
                            }
                        }
                        contentFor[lhs] = (prevName, output.count)
                        output.append("\(editor.indentationString(level: 2))\(lhs) = \(prevName)")
                    }
                } else {
                    let nidx = idx + 1
                    let nextName = "dict\(nidx)"
                    if idx < subDicts.count && sameHeirarchy {
                        if key == subDicts[idx] {
                            continue
                        } else {
                            sameHeirarchy = false
                        }
                    }
                    output.append("\(editor.indentationString(level: 2))\(nidx > subDicts.count ? "var " : "")\(nextName) = \(dName)[\"\(key)\"] as? [String: Any] ?? [String: Any]()")
                }
            }
            if keys.count > 1 {
                for i in 0 ..< keys.count - 1 {
                    if i < subDicts.count {
                        subDicts[i] = keys[i]
                    } else {
                        subDicts.append(keys[i])
                    }
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

    fileprivate func createInitWithCoder(lineIndex: Int, customLines: [String]?, editor: SourceZcodeCommand) -> Int {
        let codingOverride = !(classInheritence!.contains("NSCoding") || classInheritence!.contains("NSSecureCoding"))
        var output = [String]()
        let initAccess =  classAccess == "open" ? "public " : "\(classAccess) "

        output.append("\(editor.indentationString(level: 1))\(initAccess)required init?(coder aDecoder: NSCoder) { // Generated")

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

    fileprivate func createEncodeWithCoder(lineIndex: Int, customLines: [String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        let codingOverride = !(classInheritence!.contains("NSCoding") || classInheritence!.contains("NSSecureCoding"))
        let codingOverrideString = codingOverride ? "override " : ""
        output.append("\(editor.indentationString(level: 1))\(classAccess.isEmpty ? "" : "\(classAccess) ")\(codingOverrideString)func encode(with aCoder: NSCoder) { // Generated")
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

    fileprivate func createCopy(lineIndex: Int, customLines: [String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        let codingOverride = !classInheritence!.contains("NSCopying")
        output.append("\(editor.indentationString(level: 1))\(classAccess.isEmpty ? "" : "\(classAccess) ")\(codingOverride ? "override " : "")func copy(with zone: NSZone? = nil) -> Any { // Generated")
        let typeStr: String
        if let name = className {
            typeStr = "\(name).self"
        } else {
            typeStr = "\(type(of:self))"
        }
        output.append("\(editor.indentationString(level: 2))let aCopy = try! NSKeyedUnarchiver.unarchivedObject(ofClasses: [\(typeStr)], from: NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true))!")
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

   fileprivate  func createCustomInit(lineIndex: Int, customLines: [String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        let initAccess =  classAccess == "open" ? "public " : (classAccess.isEmpty ? "" : "\(classAccess) ")
        let params = variables.compactMap { return $0.getInitParam() }.joined(separator: ", ")
        output.append("\(editor.indentationString(level: 1))\(initAccess)init(\(params)) { // Generated Init")
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


extension SourceZcodeCommand {

    func cast(command: CommandOptions) {
        let classRegex = Regex("(class|struct) +([^ :]+)[ :]+(.*)\\{ *$", options: [.anchorsMatchLines])
        let varRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *\\{* *(?://! *(?:= *([^ ]+))? *(?:(v?)\"([^\"]+)\")?)?")
        let customVarRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *//! *(?:= *([^ ]+))? *custom")
        let dictRegex = Regex("(var|let) +([^: ]+?) *: *(\\[.*?: *[^ ]*\\][!?]?) *\\{* *(?://! *(?:= *([^ ]+))? (v?)\"([^ ]+)\")?")
        let customDictRegex = Regex("(var|let) +([^: ]+?) *: *(\\[.*?: *[^ ]*\\][!?]?) *//! *(?:= *(nil))? *custom")
        let skipForJSON = Regex("//! *ignore *json *$", options: [.caseInsensitive])
        let ignoreVarRegex = Regex("//! *ignore *$", options: [.caseInsensitive])
        let accessRegex = Regex("(public|private|internal|open)")
        let disableLogging = Regex("//! *nolog")
        let superTagRegex = Regex("//! +super +\"([^\"]+)\"")
        var parseInfo: ParseInfo?
        var startClassLine = 0
        let caseCommand = Regex("//! *zcode: +case +([a-z]+)", options: [.caseInsensitive])
        let logCommand = Regex("//! *zcode: +logger +(on|off|true|false)", options: [.caseInsensitive])
        let nilCommand = Regex("//! *zcode: +emptyisnil +(on|off|true|false)", options: [.caseInsensitive])
        let signature = Regex("// zcode fingerprint =")
        let isStatic = Regex("\\b(class|static)\\b.*\\b(var|let)\\b")

        var functions = [Function: FunctionInfo]()
        functions[.copy] = FunctionInfo(expression: "func copy(with zone: NSZone? = nil) -> Any { // Generated", condition: { (command, info) in
            (command.contains(.cast) && info.classInheritence!.contains("NSCopying")) || command.contains(.copying)
        }, create: { (line, info, custom, editor) -> Int in
            info.createCopy(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.encode] = FunctionInfo(expression: "func encode(with aCoder: NSCoder) { // Generated", condition: { (command, info) in
            (command.contains(.cast) && (info.classInheritence!.contains("NSCoding") || info.classInheritence!.contains("NSSecureCoding"))) || command.intersects([.copying, .coding])
        }, create: { (line, info, custom, editor) in
            info.createEncodeWithCoder(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.initWithCoder] = FunctionInfo(expression: "init?(coder aDecoder: NSCoder) { // Generated", condition: { (command, info) in
            (command.contains(.cast) && (info.classInheritence!.contains("NSCoding") || info.classInheritence!.contains("NSSecureCoding"))) || command.intersects([.coding, .copying])
        }, create: { (line, info, custom, editor) in
            info.createInitWithCoder(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.dictionaryRepresentation] = FunctionInfo(expression: "func dictionaryRepresentation() -> [String: Any] { // Generated", condition: { (command, info) in
            command.contains(.cast)
        }, create: { (line, info, custom, editor) in
            info.createDictionaryRepresentation(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.read] = FunctionInfo(expression: "func read(from dict: JSONDictionary) { // Generated", condition: { (command, info) in
            command.contains(.read)
        }, create: { (line, info, custom, editor) in
            info.createRead(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.initDictionary] = FunctionInfo(expression: "init?(dictionary dict: JSONDictionary) { // Generated", condition: { (command, info) in
            command.contains(.cast)
        }, create: { (line, info, _, editor) in
            info.createInitWithDict(lineIndex: line, editor: editor)
        })
        functions[.customInit] = FunctionInfo(expression: "// Generated Init", condition: { (command, _) -> Bool in
            command.contains(.customInit)
        }, create: { (line, info, custom, editor) in
            info.createCustomInit(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.multipart] = FunctionInfo(expression: "func multipartDictionaryRepresentation() -> [String: Any] { // Generated", condition: { (command, _) -> Bool in
            command.contains(.multipart)
        }, create: { (line, info, custom, editor) in
            info.createMultipartDictionaryRepresentation(lineIndex: line, customLines: custom, editor: editor)
        })


        var linesForChecksum = [String]()
        var signatureLine: Int? = nil
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
                } else if signature.match(line) {
                    signatureLine = lineIndex
                }

            }
            
            if let info = parseInfo {
                if braceLevel == 0 {
                    if priorBraceLevel == 1 {
                        if cursorPosition.isZero || (lineIndex >= cursorPosition.line && cursorPosition.line >= startClassLine) {
                            let f = functions.values.sorted(by: {
                                if let firstStart = $0.start {
                                    if let secondStart = $1.start {
                                        return firstStart > secondStart
                                    } else {
                                        return true
                                    }
                                } else {
                                    return false
                                }
                            })
                            for value in f {
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
                            }

//                            if !cursorPosition.isZero {
//                                stop = true
//                            }
                        }
                        for (key,_) in functions {
                            functions[key]?.start = nil
                            functions[key]?.end = nil
                            functions[key]?.custom = nil
                        }
                        parseInfo = nil
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
                    if ignoreVarRegex.match(line) {
                        return // ignore these
                    } else if disableLogging.match(line) {
                        info.disableHouzzzLogging = true
                        return
                     } else if let matches: [String?] = customDictRegex.matchGroups(line) {
                        if isStatic.match(line) {
                            return
                        }
                        linesForChecksum.append(line)
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: false, key: nil, useCustom: true, skip: skipForJSON.match(line), className: info.className!))
                    } else if let matches: [String?] = dictRegex.matchGroups(line) {
                        if isStatic.match(line) {
                            return
                        }
                        linesForChecksum.append(line)
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: false, skip: skipForJSON.match(line), className: info.className!))
                    } else if let matches: [String?] = customVarRegex.matchGroups(line) {
                        if isStatic.match(line) {
                            return
                        }
                        linesForChecksum.append(line)
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: false, key: nil, useCustom: true, skip: skipForJSON.match(line), className: info.className!))
                    } else if let matches: [String?] = varRegex.matchGroups(line) {
                        if isStatic.match(line) {
                            return
                        }
                        linesForChecksum.append(line)
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: false, skip: skipForJSON.match(line), className: info.className!))
                    } else if let matches: [String?] = superTagRegex.matchGroups(line) {
                        if let str = matches[1] {
                            info.superTag = str
                        }
                    }
                    if braceLevel == 2 {
                        for (_,info) in functions {
                            if line.contains(info.expression) {
                                info.start = lineIndex
                                info.inside = true
                                return
                            }
                        }
                    }
                } else if braceLevel == 2 {
                    for (_,info) in functions {
                        if info.inside && line.contains(startReadCustomPattern) {
                            info.inBlock = true
                            info.custom = nil
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

        linesForChecksum.append("")
        let md5 = linesForChecksum.joined(separator: "\n").md5()
        let sigline = "// zcode fingerprint = \(md5)"
        if let line = signatureLine {
            deleteLines(from: line, to: line + 1)
            insert([sigline], at: line)
        } else {
            append("\(sigline)\n")
        }
        print(sigline)
        finish()
    }
}


extension String {
   public func md5() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        if let d = data(using: .utf8) {
            _ = d.withUnsafeBytes { (body: UnsafePointer<UInt8>) in
                CC_MD5(body, CC_LONG(d.count), &digest)
            }
        }

        var digestHex = [String]()
        for index in 0 ..< Int(CC_MD5_DIGEST_LENGTH) {
            let snippet = String(format: "%02x", digest[index])
            digestHex.append(snippet)
        }

        return digestHex.joined(separator: "")
    }
}
