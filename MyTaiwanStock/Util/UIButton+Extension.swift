//
//  UIButton+Extension.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/18/22.
//
import UIKit
import Foundation

extension UIButton {

    func centerTextAndImage(spacing: CGFloat) {
        let insetAmount = spacing / 2
        let isRTL = UIView.userInterfaceLayoutDirection(for: semanticContentAttribute) == .rightToLeft
        if isRTL {
           imageEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount, bottom: 0, right: -insetAmount)
           titleEdgeInsets = UIEdgeInsets(top: 0, left: -insetAmount, bottom: 0, right: insetAmount)
           contentEdgeInsets = UIEdgeInsets(top: 0, left: -insetAmount, bottom: 0, right: -insetAmount)
        } else {
           imageEdgeInsets = UIEdgeInsets(top: 0, left: -insetAmount, bottom: 0, right: insetAmount)
           titleEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount, bottom: 0, right: -insetAmount)
           contentEdgeInsets = UIEdgeInsets(top: 0, left: insetAmount, bottom: 0, right: insetAmount)
        }
    }
    
    func leftImage(image: UIImage, renderMode: UIImage.RenderingMode) {
            self.setImage(image.withRenderingMode(renderMode), for: .normal)
            self.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: image.size.width / 2)
            self.contentHorizontalAlignment = .left
            self.imageView?.contentMode = .scaleAspectFit
        }
    func moveImageLeftTextCenter(image : UIImage, imagePadding: CGFloat, renderingMode: UIImage.RenderingMode){

          self.setImage(image.withRenderingMode(renderingMode), for: .normal)
          guard let imageViewWidth = self.imageView?.frame.width else{return}
          guard let titleLabelWidth = self.titleLabel?.intrinsicContentSize.width else{return}
          self.contentHorizontalAlignment = .left
          let imageLeft = imagePadding - imageViewWidth / 2
          let titleLeft = (bounds.width - titleLabelWidth) / 2 - imageViewWidth
          imageEdgeInsets = UIEdgeInsets(top: 0.0, left: imageLeft, bottom: 0.0, right: 0.0)
          titleEdgeInsets = UIEdgeInsets(top: 0.0, left: titleLeft , bottom: 0.0, right: 0.0)
        
        print("imageLeft \(imageLeft)")
        print("titleLeft \(titleLeft)")
      }
}
