//
//  Fee.swift
//  MyTaiwanStock
//
//  Created by YKLin on 9/19/22.
//

import Foundation

struct Fee {
    let feePercentValues = (1...10).map{ int -> String in
        if int < 10 {
            return "\(int)折"
        } else {
            return "無折扣"
        }
    }
    let feeCategory = ["折數","盤中零股", "自訂(元)"]
    
    func calFee(price: Float, amount: Float, multiplier: Float) -> Float{
        let total = price*amount*multiplier*0.001425
        return total<20 ? 20 : total
    }
    
}
