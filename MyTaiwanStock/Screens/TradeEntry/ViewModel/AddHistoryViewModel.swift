//
//  AddHistoryViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import Foundation

/// What the add-record screen needs from storage.
protocol RecordSaving {
    func saveNewRecord(
        stockNo: String, price: Float, amount: Int, reason: String, buyOrSellStatus: Int, date: Date,
        fee: Int?, tax: Int?)
}

extension NetworkServiceImpl: RecordSaving {}

/// The state behind the add-record screen: the side, the tax category, and the fee and the tax as the two
/// fields show them. A field the user typed in keeps the typed text; the other one follows the price, the
/// shares, the side and the category.
final class AddHistoryViewModel {
    var date = Date()
    var memo = ""
    private(set) var side: TradeSide = .buy
    private(set) var taxCategory: TaxCategory = .stock
    private(set) var feeText = ""
    private(set) var taxText = ""
    /// Runs after a computed value changed, so the screen shows the new text. It does not run for text the
    /// user typed, which the field already shows.
    var onChange: (() -> Void)?

    private let feeSettings: () -> FeeSettings
    private let repository: RecordSaving
    private let validation = ValidInputService()
    private var priceText: String?
    private var amountText: String?
    private var feeIsManual = false
    private var taxIsManual = false

    init(
        feeSettings: @escaping () -> FeeSettings = { FeeSettings.current() },
        repository: RecordSaving = NetworkServiceImpl()
    ) {
        self.feeSettings = feeSettings
        self.repository = repository
    }

    // MARK: input

    /// Called with the final text of both fields every time either of them changes.
    func didChange(priceText: String?, amountText: String?) {
        self.priceText = priceText
        self.amountText = amountText
        recompute()
    }

    func didSelect(side: TradeSide) {
        self.side = side
        recompute()
    }

    func didSelect(taxCategory: TaxCategory) {
        self.taxCategory = taxCategory
        recompute()
    }

    func didEditFee(_ text: String?) {
        feeText = text ?? ""
        feeIsManual = true
    }

    func didEditTax(_ text: String?) {
        taxText = text ?? ""
        taxIsManual = true
    }

    /// A field that is left empty shows the computed value again and goes back to following the inputs.
    func didEndEditingFee() {
        guard isBlank(feeText) else { return }
        feeIsManual = false
        recompute()
    }

    func didEndEditingTax() {
        guard isBlank(taxText) else { return }
        taxIsManual = false
        recompute()
    }

    // MARK: saving

    /// Writes the record with the fee and the tax the fields show. A buy never pays tax, so its tax is 0
    /// whatever the tax field holds.
    func save(stockNo: String, priceText: String?, amountText: String?) throws {
        let price = try validation.validStockPriceInput(priceText)
        guard price.isFinite else { throw ValidationError.invalidPrice }
        let amount = try validation.validStockAmountInput(amountText)
        let fee = try validation.validFeeOrTaxInput(feeText)
        let tax = side == .sell ? try validation.validFeeOrTaxInput(taxText) : 0
        repository.saveNewRecord(
            stockNo: stockNo, price: price, amount: amount, reason: memo, buyOrSellStatus: side.rawValue,
            date: date, fee: fee, tax: tax)
    }

    // MARK: computing

    private func recompute() {
        let computed = computedFeeAndTax()
        if !feeIsManual { feeText = computed.map { String($0.fee) } ?? "" }
        if !taxIsManual { taxText = computed.map { String($0.tax) } ?? "" }
        onChange?()
    }

    private func computedFeeAndTax() -> FeeAndTax? {
        guard let price = Self.price(from: priceText), let shares = Self.shares(from: amountText) else {
            return nil
        }
        return FeeCalculator.calculate(
            price: price, shares: shares, side: side, settings: feeSettings(), taxCategory: taxCategory)
    }

    /// A plain number: digits and at most one point. Anything else, such as "1e5", is not a price.
    private static func price(from text: String?) -> Decimal? {
        guard let text = text?.trimmingCharacters(in: .whitespaces), !text.isEmpty,
              text.allSatisfy({ $0.isASCII && ($0.isNumber || $0 == ".") }),
              text.filter({ $0 == "." }).count <= 1
        else { return nil }
        return Decimal(string: text)
    }

    private static func shares(from text: String?) -> Int? {
        text.flatMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }

    private func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
