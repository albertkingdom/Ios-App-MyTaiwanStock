//
//  CustomTabBarViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/27/22.
//

import UIKit

class CustomTabBarViewController: UITabBarController, UITabBarControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.delegate = self
        // Do any additional setup after loading the view.
    }
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        // on select tab, always show the root of embedded navigation controller
        (viewController as? UINavigationController)?.popToRootViewController(animated: true)
        return true
    }
}
