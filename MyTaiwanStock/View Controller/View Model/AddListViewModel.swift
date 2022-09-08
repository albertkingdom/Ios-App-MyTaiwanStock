//
//  AddListViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//
import Combine
import Foundation
import CoreData
import FirebaseFirestore
import FirebaseFirestoreSwift
import FirebaseAuth

class AddListViewModel {
    var subscription = Set<AnyCancellable>()
    //var listNames = Observable<[String]>([])
    var listNamesCombine = CurrentValueSubject<[String],Never>([])
//    var coreDataItems: [List]! {
//        didSet {
//            self.listNames.value = coreDataItems.map({ list in
//                list.name!
//            })
//        }
//    }
    var coreDataItemsCombine = CurrentValueSubject<[List],Never>([])
    var context: NSManagedObjectContext!
    var onlineDBService: OnlineDBService?
    
    init(context: NSManagedObjectContext) {
        
        self.context = context
        let coreDataItems = fetchAllListFromDB()
        coreDataItemsCombine.send(coreDataItems)
        
        
        coreDataItemsCombine.sink { [weak self] list in
            let listNames = list.map({ list in
                list.name!
            })
            self?.listNamesCombine.send(listNames)
            
        }
        .store(in: &subscription)
        
        onlineDBService = OnlineDBService()
        
    }
   
    //
    func deleteList(at index:Int) {
        let deleteItem = self.coreDataItemsCombine.value[index]
        let listNameToDelete = listNamesCombine.value[index]
        deleteListFromDB(item: deleteItem)
        self.coreDataItemsCombine.value.remove(at: index)
        // delete list from online
        deleteListFromOnlineDB(listName: listNameToDelete)
    }
    //
    func updateListName(at index: Int, with newName: String) {
        let listToBeUpdate = self.coreDataItemsCombine.value[index]
        listToBeUpdate.name = newName
        self.updateList(item: listToBeUpdate)
    }
    // MARK: CORE DATA
    func saveNewListToDB(listName: String) {
        
        let newList = List(context: context)
        newList.name = listName
        do {
            try context.save()
            let lists = self.fetchAllListFromDB()
            coreDataItemsCombine.send(lists)
         
        } catch {
            print("error, \(error.localizedDescription)")
        }
        
    }
    func fetchAllListFromDB() -> [List] {
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        var allLists: [List] = []
        do {
//            self.coreDataItems = try context.fetch(fetchRequest)
            //print("lists \(self.coreDataItems)")
            allLists = try context.fetch(fetchRequest)
            
        } catch let error {
            print(error.localizedDescription)
        }
        
        return allLists
    }
    func deleteListFromDB(item: List) {
        context.delete(item)
        do {
            try context.save()
            
        } catch {
            print("error, \(error.localizedDescription)")
        }
    }
    func updateList(item: List) {
        
        do {
            try context.save()
            let lists = fetchAllListFromDB()
            coreDataItemsCombine.send(lists)
        } catch {
            print("error, \(error.localizedDescription)")
        }
    }
    func getLoginAccountEmail() -> String? {
        guard let email = Auth.auth().currentUser?.email else {return nil}
        return email
    }
    // upload new list
    func uploadListToOnlineDB(listName: String) {
        onlineDBService?.uploadListToOnlineDB(listName: listName)
    }
    
    func deleteListFromOnlineDB(listName: String) {
        onlineDBService?.deleteListFromOnlineDB(listName: listName)
    }
}
