//
//  View+Extension.swift
//  StockWidgetExtension
//
//  Created by yklin on 2024/5/9.
//

import Foundation
import SwiftUI

extension View {
    
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            return  containerBackground(color, for: .widget)
        } else {
            return background(color)
        }
    }
}
