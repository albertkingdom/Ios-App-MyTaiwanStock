//
//  StockNameResolver.swift
//  MyTaiwanStock
//

import Foundation

/// Turns the stock name read from a screenshot into a stock code.
///
/// The broker screen shows names only. Both sides are normalized the same way (Unicode
/// compatibility mapping, so full-width becomes half-width, then all whitespace removed)
/// and compared exactly. There is no fuzzy matching: a name that is missing or shared by
/// more than one stock stays unresolved so the user picks the code instead of the app guessing.
struct StockNameResolver {
    /// Normalized name to the codes that carry it.
    private let codesByName: [String: [String]]

    init(entries: [StockListEntry]) {
        var codesByName: [String: [String]] = [:]
        for entry in entries {
            codesByName[Self.normalize(entry.name), default: []].append(entry.code)
        }
        self.codesByName = codesByName
    }

    /// The stock code for `name`, or nil when the name is unknown or ambiguous.
    func resolve(name: String) -> String? {
        let normalized = Self.normalize(name)
        guard !normalized.isEmpty, let codes = codesByName[normalized], codes.count == 1 else { return nil }
        return codes[0]
    }

    private static func normalize(_ name: String) -> String {
        name.precomposedStringWithCompatibilityMapping
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
    }
}
