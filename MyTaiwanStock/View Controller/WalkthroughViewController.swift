//
//  WalkthroughViewController.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/6/18.
//

import UIKit

class WalkthroughViewController: UIViewController {
    var targetView: UIView?
    var hintText: String?
    let backgroundView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        return v
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear
        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let targetView = self.targetView, let hintText = self.hintText {
                self.showOverlay(for: targetView, text: hintText)
            }
        }
    }
    
    func showOverlay(for view: UIView, text: String) {
        let originalFrame: CGRect = view.convert(view.bounds, to: self.view)
        // Calculate the new frame to be twice the size of the original frame
        let overlayFrame = CGRect(
            x: originalFrame.origin.x - originalFrame.size.width / 2,
            y: originalFrame.origin.y - originalFrame.size.height / 2,
            width: originalFrame.size.width * 2,
            height: originalFrame.size.height * 2
        )
        
        // Debugging: Print the frame values
        print("Original Frame: \(originalFrame)")
        print("Overlay Frame: \(overlayFrame)")
        let overlayView = UIView(frame: overlayFrame)

        let maskLayer = CAShapeLayer()
        maskLayer.frame = backgroundView.bounds
        maskLayer.fillColor = UIColor.black.cgColor

        let path = UIBezierPath(rect: backgroundView.bounds)
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        // Append the overlay image to the path so that it is subtracted.
        path.append(
            UIBezierPath(roundedRect: overlayFrame, 
                         cornerRadius: overlayFrame.width/2)
        )

        maskLayer.path = path.cgPath
        
        backgroundView.layer.mask = maskLayer
        
        
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        // Position the label beside the target view
        let labelWidth: CGFloat = 150
        let labelHeight: CGFloat = 50
        let labelX: CGFloat = overlayFrame.maxX + 10 // 10 points padding
        let labelY: CGFloat = overlayFrame.midY - (labelHeight / 2) // Vertically centered
        if labelX + labelWidth > self.view.bounds.width {
            label.frame = CGRect(x: overlayFrame.minX - labelWidth - 10, y: labelY, width: labelWidth, height: labelHeight)
        } else {
            label.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: labelHeight)
        }
        
        self.view.addSubview(label)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(removeOverlay))
        self.view.addGestureRecognizer(tapGesture)
        
    }
    
    @objc func removeOverlay(_ sender: UITapGestureRecognizer) {
        self.dismiss(animated: true, completion: nil)
    }
}
