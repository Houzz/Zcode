//
//  CodableCommand.swift
//  ZCode
//
//  Created by Guy on 01/12/2019.
//  Copyright © 2019 Houzz. All rights reserved.
//

import Foundation

private enum Function {
    case codingKeys
    case initDecoder
    case encode
}

fileprivate extension VarInfo {
    func decodeStatement() -> String {
        var output = [String]()
        output.append("\(name) =")
        var statements = [String]()
        var needTry = true
        for (idx,k) in key.enumerated() {
            let splitK = k.split(separator: "/")
            var collect = "container"
            for (idx2, singleK) in splitK.enumerated() {
                if idx2 == splitK.count - 1 {
                    switch type {
                    case "Double", "CGFloat", "Int","String","Bool","URL", "UIImage", "UIColor":
                        collect.append(".decode\(type)\(self.optional  || idx < key.count - 1 ? "IfPresent" : "")(forKey: .\(singleK))")
                    default:
                        collect.append(".decode\(self.optional  || idx < key.count - 1 ? "IfPresent" : "")(\(type).self, forKey: .\(singleK))")
                    }
                } else {
                    let opt = self.key.count > 1
                    collect.append(".nestedContainer\(opt ? "IfPresent" : "")(keyedBy: CodingKeys.self, forKey: .\(singleK))\(opt ? "?" : "")")
                }
            }
            if type == "String" && Defaults.nilEmptyStrings && optional {
                collect = "nilEmpty(try \(collect))"
                needTry = false
            }
            statements.append(collect)
        }
        output.append("\(needTry ? "try " : "")\(statements.joined(separator: " ?? "))")
        if  defaultValue != nil {
            output.insert("do {", at: 0)
            output.append("} catch {}")
        }
        return output.joined(separator: " ")
    }
    
    func encodeStatement() -> String {
        var collect = "try container"
        let items = key[0].split(separator: "/")
        for (idx,single) in items.enumerated() {
            if idx < items.count - 1 {
                collect += ".nestedContainer(keyedby: CodingKeys.self, forKey: .\(single))"
            } else {
                switch type {
                case "URL", "UIImage", "UIColor":
                    collect += ".encode\(type)\(optional ? "IfPresent": "")(\(name), forKey: .\(single))"
                default:
                    collect +=  ".encode\(optional ? "IfPresent": "")(\(name), forKey: .\(single))"
                }
            }
        }
        return collect
    }
}

extension ParseInfo {
    fileprivate func createEnum(lineIndex: Int, customLines:[String]?, editor: SourceZcodeCommand) -> Int {
        if variables.isEmpty {
            return 0
        }
        var output = [String]()
        output.append("\(editor.indentationString(level: 1))private enum CodingKeys: String, CodingKey { // Generated")
        var allKeys = Set<String>()
        for variable in variables {
            guard !variable.skip || (variable.isLet && variable.defaultValue != nil) else {
                continue
            }
            variable.key.forEach { $0.split(separator: "/").forEach { word in allKeys.insert(String(word)) } }
        }
        for key in allKeys.sorted() {
            output.append("\(editor.indentationString(level: 2))case \(key)")
        }
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }
    
    fileprivate func createEncode(lineIndex: Int, customLines:[String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        var override = ""
        if !(classInheritence ?? []).contains("Codable") && !isStruct {
            override = "override "
        }
        output.append("\(editor.indentationString(level: 1))\(override)\(classAccess.isEmpty ? "" : "\(classAccess == "private" ? "fileprivate" : classAccess) ")func encode(to encoder: Encoder) throws { // Generated")
        if !variables.isEmpty {
            output.append("\(editor.indentationString(level: 2))var container = encoder.container(keyedBy: CodingKeys.self)")
            for variable in variables {
                if variable.skip || (variable.isLet && variable.defaultValue != nil)  {
                    continue
                }
                output.append("\(editor.indentationString(level: 2))\(variable.encodeStatement())")
            }
        }
        if !override.isEmpty {
            output.append("\(editor.indentationString(level: 2))try super.encode(to: encoder)")
        }
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }
    
    fileprivate func createInitDecoder(lineIndex: Int, customLines:[String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        var l = [String]()
        if classAccess == "open" {
            l.append("public")
        } else if classAccess == "private" {
            l.append("fileprivate")
        } else if !classAccess.isEmpty {
            l.append(classAccess)
        }
        if !isStruct {
            l.append("required")
        }
        let override: Bool
        if !(classInheritence ?? []).contains("Codable") && !isStruct {
            //l.append("override")
            override = true
        } else {
            override = false
        }
        l.append("init(from decoder: Decoder) throws { // Generated")
        output.append("\(editor.indentationString(level: 1))\(l.joined(separator: " "))")
        if !variables.isEmpty {
            output.append("\(editor.indentationString(level: 2))let container = try decoder.container(keyedBy: CodingKeys.self)")
            for variable in variables {
                if variable.skip || (variable.isLet && variable.defaultValue != nil) {
                    continue
                }
                output.append("\(editor.indentationString(level: 2))\(variable.decodeStatement())")
            }
        }
        output.append("\(editor.indentationString(level: 2))\(startReadCustomPattern)")
        if let customLines = customLines {
            output += customLines
        }
        if override {
            if !(customLines ?? []).joined().contains("super.init") {
                if let superTag = superTag {
                    output.append("\(editor.indentationString(level: 2))let superDecoder = try container.superDecoder(forKey: .\(superTag))")
                    output.append("\(editor.indentationString(level: 2))try super.init(from: superDecoder)")
                } else {
                    output.append("\(editor.indentationString(level: 2))try super.init(from: decoder)")
                }
            }
        }
        output.append("\(editor.indentationString(level: 1))}")
        editor.insert(output, at: lineIndex)
        return output.count
    }
}

struct CaseInfo {
    let name: String
    let payloadName: String?
    let payloadType: String?
    
    init(name: String, payloadName: String?, payloadType: String?) {
        self.name = name
        self.payloadType = (payloadType ?? "").isEmpty ? nil : payloadType
        if let g1 = payloadName?.components(separatedBy: " ").first, g1 != "_" && !g1.isEmpty {
            self.payloadName = g1
        } else {
            self.payloadName = nil
        }
    }
    
    var caseStatement: String {
        var s = "case .\(name)"
        if let _ = payloadType {
            s = "\(s)(let v)"
        }
        return "\(s):"
    }
    
    var decodeStatement: String {
        if let type = payloadType {
            return "self = .\(name)(try container.decode(\(type).self, forKey: .payload))"
        } else {
            return "self = .\(name)"
        }
    }
}

class EnumInfo {
    var cases: [CaseInfo] = []
    var generatedRanges = [Range<Int>]()
}

extension SourceZcodeCommand {
    private func generateKeys(cases: [CaseInfo], at line: Int) -> Int {
        var lines = [String]()
        lines.append("\(indentationString(level: 1))private enum CodingKeys: String, CodingKey { // Generated")
        lines.append("\(indentationString(level: 2))case type")
        lines.append("\(indentationString(level: 2))case payload")
        lines.append("\(indentationString(level: 1))}")
        insert(lines, at: line)
        return lines.count
    }
    
    private func generateEnumEncode(cases: [CaseInfo], at line: Int) -> Int {
        var lines = [String]()
        lines.append("\(indentationString(level: 1))public func encode(to encoder: Encoder) throws { // Generated")
        lines.append("\(indentationString(level: 2))var container = encoder.container(keyedBy: CodingKeys.self)")
        lines.append("\(indentationString(level: 2))switch self {")
        for (idx,aCase) in cases.enumerated() {
            lines.append("\(indentationString(level: 2))\(aCase.caseStatement)")
            lines.append("\(indentationString(level: 3))try container.encode(\(idx), forKey: .type)")
            if aCase.payloadType != nil {
                let symbol: String
                if let name = aCase.payloadName {
                    symbol = "\(name): "
                } else {
                    symbol = ""
                }
                lines.append("\(indentationString(level: 3))try container.encode(\(symbol)v, forKey: .payload)")
            }
            if idx < cases.count - 1 {
                lines.append("")
            }
        }
        lines.append("\(indentationString(level: 2))}")
        lines.append("\(indentationString(level: 1))}")
        insert(lines, at: line)
        return lines.count
    }
    
    private func generateEnumInit(cases: [CaseInfo], at line: Int) -> Int {
        var lines = [String]()
        lines.append("\(indentationString(level: 1))public init(from decoder: Decoder) throws { // Generated")
        lines.append("\(indentationString(level: 2))let container = try decoder.container(keyedBy: CodingKeys.self)")
        lines.append("\(indentationString(level: 2))switch try container.decode(Int.self, forKey: .type) {")
        for (idx,aCase) in cases.enumerated() {
            lines.append("\(indentationString(level: 2))case \(idx):")
            lines.append("\(indentationString(level: 3))\(aCase.decodeStatement)")
            lines.append("")
        }
        lines.append("\(indentationString(level: 2))default:")
        lines.append("\(indentationString(level: 3))throw EnumDecodeError.unknownCase")
        lines.append("\(indentationString(level: 2))}")
        lines.append("\(indentationString(level: 1))}")
        insert(lines, at: line)
        return lines.count
    }
    
    func codable() {
        let classRegex = Regex("(class|struct) +([^ :]+)[ :]+(.*)\\{ *$", options: [.anchorsMatchLines])
        let varRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *(?:= *([^ ]+))? *\\{* *(?://! *(?:(v?)\"([^\"]+)\")?)?")
        let customVarRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *//! *(?:= *([^ ]+))? *custom")
        let ignoreVarRegex = Regex("//! *ignore *$", options: [.caseInsensitive])
        let accessRegex = Regex("(public|private|internal|open)")
        let disableLogging = Regex("//! *nolog")
        let superTagRegex = Regex("//! +super +\"([^\"]+)\"")
        let enumRegex = Regex("enum .*:.*\\bCodable\\b")
        let caseRegex = Regex("case +([^ \\(]+)(?:\\(([^ :]*? ?(?:[^ :]*?))?:? *([^ ]+)\\))?")
        
        var parseInfo: ParseInfo?
        var startClassLine = 0
        let caseCommand = Regex("//! *zcode: +case +([a-z]+)", options: [.caseInsensitive])
        let logCommand = Regex("//! *zcode: +logger +(on|off|true|false)", options: [.caseInsensitive])
        let nilCommand = Regex("//! *zcode: +emptyisnil +(on|off|true|false)", options: [.caseInsensitive])
        let signature = Regex("// zcode fingerprint =")
        let isStatic = Regex("\\b(class|static)\\b.*\\b(var|let)\\b")
        
        
        var functions = [Function: FunctionInfo]()
        functions[.codingKeys] = FunctionInfo(expression: "private enum CodingKeys: String, CodingKey { // Generated", condition: { (_, _) -> Bool in
            true
        }, create: { (lineIndex, info, customLines, editor) -> Int in
            info.createEnum(lineIndex: lineIndex, customLines: customLines, editor: editor)
        })
        functions[.encode] = FunctionInfo(expression: "func encode(to encoder: Encoder) throws { // Generated", condition: { (_, _) -> Bool in
            true
        }, create: { (line, info, custom, editor) -> Int in
            info.createEncode(lineIndex: line, customLines: custom, editor: editor)
        })
        functions[.initDecoder] = FunctionInfo(expression: "init(from decoder: Decoder) throws { // Generated", condition: { (_, _) -> Bool in
            true
        }, create: { (line, info, custom, editor) -> Int in
            info.createInitDecoder(lineIndex: line, customLines: custom, editor: editor)
        })
        
        
        var linesForChecksum = [String]()
        var signatureLine: Int? = nil
        var enumInfo: EnumInfo? = nil
        var startGen: Int? = nil
        var insertFingerprint = false
        Defaults.override(.keyCase, value: CaseType.none)
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
                                } else {
                                    insert([""], at: lineIndex, select: false)
                                    _ = value.create(lineIndex + 1, info, value.custom, self)
                                }
                            }
                            insertFingerprint = true
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
                    } else if let matches: [String?] = customVarRegex.matchGroups(line) {
                        if isStatic.match(line) {
                            return
                        }
                        linesForChecksum.append(line)
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: false, key: nil, useCustom: true, skip: ignoreVarRegex.match(line), className: info.className!))
                    } else if let matches: [String?] = varRegex.matchGroups(line) {
                        if isStatic.match(line) {
                            return
                        }
                        linesForChecksum.append(line)
                        info.variables.append(VarInfo(name: matches[2]!, isLet: matches[1]! == "let", type: matches[3]!, defaultValue: matches[4], asIsKey: !(matches[5]?.isEmpty ?? true), key: matches[6], useCustom: false, skip: ignoreVarRegex.match(line), className: info.className!))
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
            } else if let info = enumInfo {
                switch braceLevel {
                case 0:
                    _ = generateEnumInit(cases: info.cases, at: lineIndex)
                    _ = generateEnumEncode(cases: info.cases, at: lineIndex)
                    _ = generateKeys(cases: info.cases, at: lineIndex)
                    for range in info.generatedRanges.reversed() {
                        deleteLines(from: range.lowerBound, to: range.upperBound + 1)
                    }
                    enumInfo = nil
                case 1:
                    if let matches = caseRegex.matchGroups(line), let name = matches[1] {
                        info.cases.append(CaseInfo(name: name, payloadName: matches[2], payloadType: matches[3]))
                    }
                    if priorBraceLevel > 1, let low = startGen {
                        startGen = nil
                        info.generatedRanges.append(low ..< lineIndex)
                    }
                case 2:
                    if line.hasSuffix("{ // Generated") {
                        startGen = lineIndex
                    }
                default:
                    break
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
            } else if braceLevel == 1 && priorBraceLevel == 0, enumRegex.match(line) {
                enumInfo = EnumInfo()
            }
        }
        
        if insertFingerprint {
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
        }
        finish()
    }
}
