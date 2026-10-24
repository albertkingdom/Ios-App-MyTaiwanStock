//
//  FeeTaxFields.swift
//  MyTaiwanStock
//

import Foundation

/// The fee and the tax of one trade as two text fields show them. A field the user typed in keeps the typed
/// text; the other one follows the estimate. Manual entry and the screenshot import share these rules.
struct FeeTaxFields: Equatable {
    private(set) var feeText: String
    private(set) var taxText: String
    private(set) var feeIsManual: Bool
    private(set) var taxIsManual: Bool

    init(feeText: String = "", taxText: String = "", feeIsManual: Bool = false, taxIsManual: Bool = false) {
        self.feeText = feeText
        self.taxText = taxText
        self.feeIsManual = feeIsManual
        self.taxIsManual = taxIsManual
    }

    /// The fee and the tax as numbers; nil while the text is empty or not a whole number from 0 to 2147483647.
    var fee: Int? { try? ValidInputService().validFeeOrTaxInput(feeText) }
    var tax: Int? { try? ValidInputService().validFeeOrTaxInput(taxText) }

    /// Typing keeps the text as it is, an empty text included, so the user can type a new value.
    mutating func editFee(_ text: String) {
        feeText = text
        feeIsManual = true
    }

    mutating func editTax(_ text: String) {
        taxText = text
        taxIsManual = true
    }

    /// Leaving a field empty goes back to the estimate; call `refresh` afterwards to show it.
    mutating func endEditingFee() {
        if Self.isBlank(feeText) { feeIsManual = false }
    }

    mutating func endEditingTax() {
        if Self.isBlank(taxText) { taxIsManual = false }
    }

    /// Shows the estimate in the fields the user did not type. A buy pays no tax, so a tax typed for a sell is
    /// forgotten and the estimate of 0 is shown.
    mutating func refresh(with estimate: FeeAndTax?, side: TradeSide) {
        if side == .buy { taxIsManual = false }
        if !feeIsManual { feeText = estimate.map { String($0.fee) } ?? "" }
        if !taxIsManual { taxText = estimate.map { String($0.tax) } ?? "" }
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
