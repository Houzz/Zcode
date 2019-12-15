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
    func caseStatement() -> String {
        var str = "case \(name)"
        let key = self.key[0]
        if key != name {
            str += " = \"\(key)\""
        }
        return str
    }
    
    func decodeStatement() -> String {
        var output = [String]()
        output.append("\(name) =")
        let useIfPresent: Bool
        if !isLet, let defaultV = defaultValue {
            if defaultV.contains("[") || defaultV.contains("(") {
                useIfPresent = false
            } else {
                useIfPresent = true
            }
        } else {
            useIfPresent = false
        }
        switch type {
        case "Double", "CGFloat", "Int","String","Bool","URL":
            output.append("try container.decode\(type)\(self.optional || useIfPresent ? "IfPresent" : "")(forKey: .\(name))")
        default:
            output.append("try container.decode\(self.optional || useIfPresent ? "IfPresent" : "")(\(type).self, forKey: .\(name))")
        }
        if !useIfPresent && defaultValue != nil {
            output.insert("do {", at: 0)
            output.append("} catch {}")
        } else if let defaultV = defaultValue {
            output.append("?? \(defaultV)")
        }
        return output.joined(separator: " ")
    }
    
    func encodeStatement() -> String {
        switch type {
        case "URL":
            return "try container.encode\(type)\(optional ? "IfPresent": "")(\(name), forKey: .\(name))"
        default:
            return "try container.encode\(optional ? "IfPresent": "")(\(name), forKey: .\(name))"
        }
    }
}

extension ParseInfo {
    fileprivate func createEnum(lineIndex: Int, customLines:[String]?, editor: SourceZcodeCommand) -> Int {
        var output = [String]()
        output.append("\(editor.indentationString(level: 1))private enum CodingKeys: String, CodingKey { // Generated")
        for variable in variables {
            guard !variable.skip || (variable.isLet && variable.defaultValue != nil) else {
                continue
            }
            output.append("\(editor.indentationString(level: 2))\(variable.caseStatement())")
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
        output.append("\(editor.indentationString(level: 2))var container = encoder.container(keyedBy: CodingKeys.self)")
        for variable in variables {
            if variable.skip || (variable.isLet && variable.defaultValue != nil)  {
                continue
            }
            output.append("\(editor.indentationString(level: 2))\(variable.encodeStatement())")
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
        output.append("\(editor.indentationString(level: 2))let container = try decoder.container(keyedBy: CodingKeys.self)")
        for variable in variables {
            if variable.skip || (variable.isLet && variable.defaultValue != nil) {
                continue
            }
            output.append("\(editor.indentationString(level: 2))\(variable.decodeStatement())")
        }
        if override {
            if let superTag = superTag {
                output.append("\(editor.indentationString(level: 2))let superDecoder = try container.superDecoder(forKey: .\(superTag)")
                output.append("\(editor.indentationString(level: 2))try super.init(from: superDecoder)")
            } else {
                output.append("\(editor.indentationString(level: 2))try super.init(from: decoder)")
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
    
    func codable() {
        let classRegex = Regex("(class|struct) +([^ :]+)[ :]+(.*)\\{ *$", options: [.anchorsMatchLines])
        let varRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *(?:= *([^ ]+))? *\\{* *(?://! *(?:(v?)\"([^\"]+)\")?)?")
        let customVarRegex = Regex("(var|let) +([^: ]+?) *: *([^ ]+) *//! *(?:= *([^ ]+))? *custom")
        let ignoreVarRegex = Regex("//! *ignore *$", options: [.caseInsensitive])
        let accessRegex = Regex("(public|private|internal|open)")
        let disableLogging = Regex("//! *nolog")
        let superTagRegex = Regex("//! +super +\"([^\"]+)\"")
        
        var parseInfo: ParseInfo?
        var startClassLine = 0
        let caseCommand = Regex("//! *zcode: +case +([a-z]+)", options: [.caseInsensitive])
        let logCommand = Regex("//! *zcode: +logger +(on|off|true|false)", options: [.caseInsensitive])
        let nilCommand = Regex("//! *zcode: +emptyisnil +(on|off|true|false)", options: [.caseInsensitive])
        let signature = Regex("// zcode codable fingerprint =")
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
        let sigline = "// zcode codable fingerprint = \(md5)"
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
