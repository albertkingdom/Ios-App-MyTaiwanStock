//
//  ViewController+extension.swift
//  MyTaiwanStock
//
//  Created by YKLin on 8/25/22.
//

import Foundation
import UIKit

extension UIViewController {
    func showToast(message: String) {

      
        let label = UILabel()
        label.text = message
        //label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 5
        label.clipsToBounds = true
        label.textAlignment = .center
        label.textColor = UIColor.white
        label.numberOfLines = 0
        
        label.alpha = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        
        
        // container
        let toastContainer = UIView(frame: CGRect())
        toastContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastContainer.alpha = 0.0
        toastContainer.layer.cornerRadius = 5;
        toastContainer.clipsToBounds  =  true
        toastContainer.translatesAutoresizingMaskIntoConstraints = false

        toastContainer.addSubview(label)
        
        self.view.addSubview(toastContainer)
        
        let saveArea = view.safeAreaLayoutGuide
        toastContainer.centerXAnchor.constraint(equalTo: saveArea.centerXAnchor, constant: 0).isActive = true
        toastContainer.leadingAnchor.constraint(greaterThanOrEqualTo: saveArea.leadingAnchor, constant: 15).isActive = true
        toastContainer.trailingAnchor.constraint(lessThanOrEqualTo: saveArea.trailingAnchor, constant: -15).isActive = true
        toastContainer.bottomAnchor.constraint(equalTo: saveArea.bottomAnchor, constant: -30).isActive = true
        toastContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 30).isActive = true
        
        
        label.centerXAnchor.constraint(equalTo: toastContainer.centerXAnchor, constant: 0).isActive = true
        label.leadingAnchor.constraint(greaterThanOrEqualTo: toastContainer.leadingAnchor, constant: 10).isActive = true
        label.trailingAnchor.constraint(lessThanOrEqualTo: toastContainer.trailingAnchor, constant: -10).isActive = true
        label.bottomAnchor.constraint(equalTo: toastContainer.bottomAnchor, constant: -5).isActive = true
        
        
        UIView.animate(withDuration: 0.5, delay: 0, options: .curveEaseIn, animations: {
            toastContainer.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 2, delay: 1, options: .curveLinear, animations: {
                toastContainer.alpha = 0
                
            }, completion: { _ in
                toastContainer.removeFromSuperview()
            })
        })
  
    }
    
    func showAlert(title: String, message: String, positiveAction: (() -> Void)?, negativeAction:(()->Void)?) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let positiveAction = UIAlertAction(title: "OK", style: .default) { _ in
            positiveAction?()
        }
        let negativeAction =  UIAlertAction(title: "Cancel", style: .cancel) { _ in
            negativeAction?()
        }
        alertVC.addAction(positiveAction)
        alertVC.addAction(negativeAction)
        present(alertVC, animated: true, completion: nil)
    }
    func showLoadingIcon() -> UIView {
        let container = UIView()
        let loadingView = UIActivityIndicatorView()
        loadingView.startAnimating()
        
        container.backgroundColor = .systemGray.withAlphaComponent(0.6)
        container.layer.cornerRadius = 15

        view.addSubview(container)
        container.addSubview(loadingView)
        
        loadingView.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 50),
            loadingView.heightAnchor.constraint(equalToConstant: 50)
        ])
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.widthAnchor.constraint(equalToConstant: 100),
            container.heightAnchor.constraint(equalToConstant: 100)
        ])
        
       return container
    }
}
