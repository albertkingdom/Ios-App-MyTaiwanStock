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


class OnlineDBService {
    //static let shared = OnlineDBService()
    private let followingList = "followingList"
    private let history = "history"
    private let db = Firestore.firestore()
    var context: NSManagedObjectContext = LocalDBService.shared.context
    
    init(context: NSManagedObjectContext?) {
//        self.context = context
    }
    init() {
//        let appDelegate = UIApplication.shared.delegate as! AppDelegate
//        self.context = appDelegate.persistentContainer.viewContext
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
    func getLocalListByListNameOrNull(listName: String) -> List? {
        let lists = fetchAllListFromDB()
        if let list = lists.first(where: { $0.name == listName }) {
            return list
        }
        return nil
    }
    func isStockNumberInLocalList(stockNumber: String, list: List) -> Bool {
        if let setOfStockNoObjects = list.stockNo {
            let stockNoStringArray:[String] = setOfStockNoObjects.map { ele -> String in
                guard let stockNo = (ele as? StockNo)?.stockNo else { return "" }
                //print(" \(stockNo)")
                return stockNo
            }
            if stockNoStringArray.contains(stockNumber) {
                return true
            }
            
        }
        return false
    }
    func getAllListAndStocksFromOnlineDBAndSaveToLocal(completion: (() -> Void)?) {
        guard let email = getLoginAccountEmail() else {return}
        db.collection(followingList)
            .whereField("email", isEqualTo: email)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
            
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")
                        do {
                            let favList: FavList = try document.data(as: FavList.self)
                            print("getAllListAndStocksFromOnlineDBAndSaveToLocal favList \(favList)")
                            // list name existed in local
                            if let localList = self.getLocalListByListNameOrNull(listName: favList.name),
                               let stockNos = favList.stocks {
                                print("list name existed in local")
                                for stockNo in stockNos {
                                    if self.isStockNumberInLocalList(stockNumber: stockNo, list: localList) {
                                        return
                                    }
                                    // save new stockNo to local DB
                                    self.saveNewStockNumberToDB(stockNumber: stockNo, list: localList)
                                }
                                return
                            }
                            
                            // list name not existed in local, write lists and stocks to core data
                            self.saveOnlineDataToLocalDB(listName: favList.name, stockNoStrings: favList.stocks)
                            completion?()
                        } catch let error {
                            print(error)
                        }
                    }
                   
                }
                
            }
    }
    func getAllHistoryFromOnlineDBAndSaveToLocal() {
        guard let email = getLoginAccountEmail() else {return}
        db.collection(history)
            .whereField("email", isEqualTo: email)
            .getDocuments() { (querySnapshot, err) in
                if let err = err {
                    print("Error getting documents: \(err)")
                } else {
            
                    for document in querySnapshot!.documents {
                        print("\(document.documentID) => \(document.data())")
                        do {
                            let history = try document.data(as: HistoryOnline.self)
                            print("getAllHistoryFromOnlineDBAndSaveToLocal history \(history)")
                            // write  to core data
                            self.saveOnlineHistoryToLocalDB(history: history)
                        } catch let error {
                            print(error)
                        }
                    }
                   
                }
                
            }
    }
    
    func saveOnlineDataToLocalDB(listName: String, stockNoStrings: [String]?) {
        //guard let context = context else { return }
        let newList = List(context: context)
        newList.name = listName
        if let stockNoStrings = stockNoStrings {
            for stockNoString in stockNoStrings {
                let newStockNo = StockNo(context: context)
                newStockNo.stockNo = stockNoString
                newStockNo.ofList = newList
            }
        }
       
        do {
            try context.save()
         
        } catch {
            print("error, \(error.localizedDescription)")
        }
        
    }
    func saveOnlineHistoryToLocalDB(history: HistoryOnline) {
        //guard let context = context else { return }

        let newInvestHistory = InvestHistory(context: context)
        newInvestHistory.stockNo = history.stockNo
        newInvestHistory.price = Float(history.price)
        newInvestHistory.amount = Int16(history.amount)
        newInvestHistory.date = Date(timeIntervalSince1970: Double(history.time)/1000)
        newInvestHistory.status = Int16(history.status)
        
        
        do {
            try context.save()
        } catch {
            fatalError("\(error.localizedDescription)")
        }

    }
    
    func fetchAllListFromDB() -> [List]{
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        var lists: [List] = []
        do {
            let result = try context.fetch(fetchRequest)
            //print("lists \(result)")

            lists = result
        } catch let error {
            print(error.localizedDescription)
        }
        return lists
    }
    
    func saveNewStockNumberToDB(stockNumber: String, list: List) {
        //print("saveNewStockNumberToDB...\(stockNumber)")
        //guard let context = self.context else { return }

        
        let newStockNo = StockNo(context: context)
        newStockNo.stockNo = stockNumber
        newStockNo.ofList = list // set the relationship between list and stockNo
        do {
            try context.save()
        } catch {
            print("error, \(error.localizedDescription)")
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
