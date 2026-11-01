//
//  FavList.swift
//  MyTaiwanStock
//
//  Created by YKLin on 9/7/22.
//

import Foundation

struct FavList: Codable {
    let name:String
    let email:String
    let stocks:[String]?
}
