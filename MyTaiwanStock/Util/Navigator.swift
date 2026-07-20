//
//  Navigator.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/1/25.
//

import Foundation
import UIKit

protocol Navigator {
    associatedtype Destination: UIViewController
    func navigateToVC(identifier: String)
}

extension Navigator where Self: UIViewController{
    func navigateToVC(identifier: String) {
        guard let viewController = storyboard?.instantiateViewController(withIdentifier: identifier) as? Destination else {
            fatalError("Could not instantiate view controller with identifier \(identifier)")
        }
        navigationController?.pushViewController(viewController, animated: true)
    }
}
