//
//  FontManager.swift
//  MyTaiwanStock
//
//  Created by yklin on 2025/4/19.
//

import UIKit

class FontManager {
    static let shared = FontManager()
    private init() {}

    func customFont(name: String, baseSize: CGFloat, forTextStyle textStyle: UIFont.TextStyle) -> UIFont? {
        if let customFont = UIFont(name: name, size: baseSize) {
            let fontMetrics = UIFontMetrics(forTextStyle: textStyle)
            return fontMetrics.scaledFont(for: customFont)
        } else {
            print("警告：無法載入名為 '\(name)' 的客製化字體。")
            return UIFont.preferredFont(forTextStyle: textStyle)
        }
    }
}
