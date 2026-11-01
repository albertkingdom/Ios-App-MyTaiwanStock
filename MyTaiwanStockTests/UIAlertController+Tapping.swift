//
//  UIAlertController+Tapping.swift
//  MyTaiwanStockTests
//

import UIKit

extension UIAlertController {
    /// Runs what the button with this title does, as a tap would. UIKit keeps the handler private, so it
    /// is read back from the action.
    @discardableResult
    func tapButton(titled title: String) -> Bool {
        guard let action = actions.first(where: { $0.title == title }),
              let block = action.value(forKey: "handler")
        else { return false }
        typealias Handler = @convention(block) (UIAlertAction) -> Void
        unsafeBitCast(block as AnyObject, to: Handler.self)(action)
        return true
    }
}
