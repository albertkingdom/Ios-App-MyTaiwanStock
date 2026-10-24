//
//  UnreadManager.swift
//  MyTaiwanStock
//
//  Created by yklin on 2024/10/30.
//

import Foundation
import UIKit

class UnreadManager {
    static let shared = UnreadManager()
    
    private let userDefaults = UserDefaults.standard
    private let groupUnreadCountsKey = "group_unread_counts"  // 儲存格式: [String: Int]
    
    private init() {}
    
    // 取得特定群組的未讀數量
    func getUnreadCount(forGroup groupId: String) -> Int {
        let counts = userDefaults.dictionary(forKey: groupUnreadCountsKey) as? [String: Int] ?? [:]
        return counts[groupId] ?? 0
    }
    
    // 增加特定群組的未讀數量
    func incrementUnread(forGroup groupId: String) {
        var counts = userDefaults.dictionary(forKey: groupUnreadCountsKey) as? [String: Int] ?? [:]
        let currentCount = counts[groupId] ?? 0
        counts[groupId] = currentCount + 1
        userDefaults.set(counts, forKey: groupUnreadCountsKey)
        
        // 更新 app badge
        updateApplicationBadge()
        // 發送通知
        //        notifyUnreadCountChanged(forGroup: groupId)
    }
    
    // 重設特定群組的未讀數量
    func resetUnread(forGroup groupId: String) {
        var counts = userDefaults.dictionary(forKey: groupUnreadCountsKey) as? [String: Int] ?? [:]
        counts[groupId] = 0
        userDefaults.set(counts, forKey: groupUnreadCountsKey)
        
        updateApplicationBadge()
        //        notifyUnreadCountChanged(forGroup: groupId)
    }
    
    // 取得總未讀數量
    func getTotalUnreadCount() -> Int {
        let counts = userDefaults.dictionary(forKey: groupUnreadCountsKey) as? [String: Int] ?? [:]
        return counts.values.reduce(0, +)
    }
    
    // 更新應用程式角標
    private func updateApplicationBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = self.getTotalUnreadCount()
        }
    }
    
    // 發送未讀數量變化通知
    //    private func notifyUnreadCountChanged(forGroup groupId: String) {
    //        NotificationCenter.default.post(
    //            name: .unreadCountDidChange,
    //            object: nil,
    //            userInfo: [
    //                "groupId": groupId,
    //                "count": getUnreadCount(forGroup: groupId)
    //            ]
    //        )
    //    }
}
