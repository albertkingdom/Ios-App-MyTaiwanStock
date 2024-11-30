//
//  Date+Extension.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/11/30.
//
import Foundation

extension Date {
    func taiwanFormat(date: Date) -> String {
        //  convert date to following format like:  111/03/18
       
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            [.year, .month, .day], from: date)
        if var year = components.year,
            let month = components.month,
            let day = components.day
        {
            year = year - 1911
            let fullMonth = month > 9 ? "\(month)" : "0\(month)"
            let fullDay = day > 9 ? "\(day)" : "0\(day)"
            let targetDateString = "\(year)/\(fullMonth)/\(fullDay)"
            return targetDateString
        }
        return ""
    }
}
