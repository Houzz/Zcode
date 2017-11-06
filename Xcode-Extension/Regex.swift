//
//  Regex.swift
//  houzz
//
//  Created by Guy on 18/05/2016.
//
//

import Foundation

public class Regex {
    private let expression: NSRegularExpression
    private var match: NSTextCheckingResult?

    public init(_ pattern: String, options: NSRegularExpression.Options = []) {
        do {
        expression = try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            fatalError("Error: \(error.localizedDescription)")
        }
    }

    public func matchGroups(_ input: String) -> [String?]? {
        match = expression.firstMatch(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count))
        if let match = match {
            var captures = [String?]()
            for group in 0 ..< match.numberOfRanges {
                let r = match.range(at: group)
                if r.location != NSNotFound {
                    let stringMatch = input[match.range(at: group)]
                    captures.append(stringMatch)
                } else {
                    captures.append(nil)
                }
            }
            return captures
        } else {
            return nil
        }
    }

    public func match(_ input: String) -> Bool {
        match = expression.firstMatch(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count))
        return match != nil
    }

    public func replace(_ input: String, with template: String) -> String {
        return expression.stringByReplacingMatches(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count), withTemplate: template)
    }

    public func numberOfMatchesIn(_ input: String) -> Int {
        return expression.matches(in: input, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, input.count)).count
    }
}
