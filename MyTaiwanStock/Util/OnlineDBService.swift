//
//  OnlineDBService.swift
//  MyTaiwanStock
//
//  Created by YKLin on 9/7/22.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFirestoreSwift
import CoreData


protocol OnlineDBUploading {
    func uploadListToOnlineDB(listName: String)
    func uploadNewStockNoToOnlineDB(stockNumber: String, listName: String)
    func uploadHistoryToOnlineDB(stockNo: String, price: Float, amount: Int, date: Date, status: Int)
}

/// NetworkServiceImpl 用到的所有 Firestore 操作，抽出來讓測試能注入 mock，不碰正式 Firestore
protocol OnlineDBSyncing: OnlineDBUploading {
    func deleteListFromOnlineDB(listName: String)
    func renameListInOnlineDB(oldName: String, newName: String)
    func deleteStockNoFromOnlineDB(stockNo: String, listName: String)
    func deleteHistoryFromOnlineDB(where historyObject: InvestHistory)
}

struct OnlineListDocument {
    let id: String
    let name: String
    let stocks: [String]
}

struct OnlineListRenamePlan: Equatable {
    let targetID: String
    let stocks: [String]
    let deleteIDs: [String]
}

class OnlineDBService: OnlineDBSyncing {
    //static let shared = OnlineDBService()
    private let followingList = "followingList"
    private let history = "history"
    private let db = Firestore.firestore()

    init() {
    }
    func getLoginAccountEmail() -> String? {
        guard let email = Auth.auth().currentUser?.email else {return nil}
        print("getLoginAccountEmail \(email)")
        return email
    }
    // upload new list
    func uploadListToOnlineDB(listName: String) {
        
        guard let email = getLoginAccountEmail() else {return}
        let favList = FavList(name: listName, email: email, stocks: nil)
        
        let ref = db.collection(followingList).document()
        
        db.collection(followingList)
            .whereField("email", isEqualTo: email)
            .whereField("name", isEqualTo: listName)
            .getDocuments()  { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
                    
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")
                        
                    }
                    if let documents = querySnapshot?.documents,
                       documents.isEmpty {
                        do {
                            try ref.setData(from: favList)
                        } catch let error {
                            print("uploadListToOnlineDB error \(error)")
                        }
                    }
                }
            }
    }
    func uploadNewStockNoToOnlineDB(stockNumber: String, listName: String) {
        guard let email = self.getLoginAccountEmail() else { return }
        print("uploadNewStockNoToOnlineDB list \(listName) stockNo \(stockNumber)")
        db.collection(followingList)
            .whereField("email", isEqualTo: email)
            .whereField("name", isEqualTo: listName)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
            
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")
                        
                    }
                    if let documents = querySnapshot?.documents,
                       !documents.isEmpty {
                        let documentID = documents[0].documentID
                        let ref = self.db.collection(self.followingList).document(documentID)
                        ref.updateData(["stocks": FieldValue.arrayUnion([stockNumber])] )
                        
                    }
                }
            }
    }
    
    func deleteListFromOnlineDB(listName: String) {
        guard let email = getLoginAccountEmail() else {return}
        print("deleteListFromOnlineDB list \(listName)")
        db.collection(followingList)
            .whereField("email", isEqualTo: email)
            .whereField("name", isEqualTo: listName)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
            
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")
                        
                    }
                    if let documents = querySnapshot?.documents,
                       !documents.isEmpty {
                        let documentID = documents[0].documentID
                        let ref = self.db.collection(self.followingList).document(documentID)
                        ref.delete()
                    }
                }
            }
    }
    /// 決定 Firestore 改名要怎麼做。iOS 不會從 Firestore 拉清單，Android 建的同名清單
    /// 本機看不到，所以新名稱已存在時要合併進去；舊名稱若有多份文件也一併合併。
    static func makeRenamePlan(
        documents: [OnlineListDocument], oldName: String, newName: String
    ) -> OnlineListRenamePlan? {
        let oldDocuments = documents.filter { $0.name == oldName }
        guard let firstOld = oldDocuments.first else { return nil }
        let target = documents.first(where: { $0.name == newName }) ?? firstOld

        var stocks: [String] = []
        for document in [target] + oldDocuments {
            for stock in document.stocks where !stocks.contains(stock) {
                stocks.append(stock)
            }
        }
        let deleteIDs = oldDocuments.map(\.id).filter { $0 != target.id }
        return OnlineListRenamePlan(targetID: target.id, stocks: stocks, deleteIDs: deleteIDs)
    }
    func renameListInOnlineDB(oldName: String, newName: String) {
        guard let email = getLoginAccountEmail() else {return}
        print("renameListInOnlineDB list \(oldName) -> \(newName)")
        db.collection(followingList)
            .whereField("email", isEqualTo: email)
            .whereField("name", in: [oldName, newName])
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                    return
                }
                let documents = (querySnapshot?.documents ?? []).map {
                    OnlineListDocument(
                        id: $0.documentID,
                        name: $0.data()["name"] as? String ?? "",
                        stocks: $0.data()["stocks"] as? [String] ?? []
                    )
                }
                guard let plan = Self.makeRenamePlan(
                    documents: documents, oldName: oldName, newName: newName
                ) else { return }

                let collection = self.db.collection(self.followingList)
                let batch = self.db.batch()
                batch.updateData(
                    ["name": newName, "stocks": plan.stocks],
                    forDocument: collection.document(plan.targetID)
                )
                for id in plan.deleteIDs {
                    batch.deleteDocument(collection.document(id))
                }
                batch.commit { error in
                    if let error = error {
                        print("renameListInOnlineDB error \(error)")
                    }
                }
            }
    }
    func deleteStockNoFromOnlineDB(stockNo: String, listName: String) {
        guard let email = getLoginAccountEmail() else {return}
        print("deleteStockNoFromOnlineDB list \(listName) stockNo \(stockNo)")
        db.collection(followingList)
            .whereField("email", isEqualTo: email)
            .whereField("name", isEqualTo: listName)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
            
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")
                        
                    }
                    if let documents = querySnapshot?.documents,
                       !documents.isEmpty {
                        let documentID = documents[0].documentID
                        let ref = self.db.collection(self.followingList).document(documentID)
                        ref.updateData(["stocks": FieldValue.arrayRemove([stockNo])])
                    }
                }
            }
    }
    func uploadHistoryToOnlineDB(stockNo: String, price: Float, amount: Int, date: Date, status: Int) {
        guard let email = getLoginAccountEmail() else {return}
        let timeInMillis = UInt64(date.timeIntervalSince1970*1000)
        let newHistory = HistoryOnline(price: Double(price), amount: amount, stockNo: stockNo, time: timeInMillis, email: email, status: status)
        do {
            try db.collection(history).document().setData(from: newHistory)
        } catch let error {
            print("upload history to db \(error)")
        }
    }
    func deleteHistoryFromOnlineDB(where historyObject: InvestHistory) {
        guard let email = getLoginAccountEmail(),
              let date = historyObject.date
        else {return}
       
        let timeInMillis = UInt64(date.timeIntervalSince1970*1000)
        
        db.collection(history)
            .whereField("email", isEqualTo: email)
            .whereField("time", isEqualTo: timeInMillis)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {

                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")

                    }
                    if let documents = querySnapshot?.documents,
                       !documents.isEmpty {
                        let documentID = documents[0].documentID
                        let ref = self.db.collection(self.history).document(documentID)
                        ref.delete()
                    }
                }
            }
    }
}
