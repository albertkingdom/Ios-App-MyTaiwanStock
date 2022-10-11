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

    var listNamesCombine = CurrentValueSubject<[String],Never>([])

    var coreDataItemsCombine = CurrentValueSubject<[List],Never>([])
    var context: NSManagedObjectContext!
    var localDB: LocalDBService!
    var onlineDBService: OnlineDBService?
    
    init(context: NSManagedObjectContext) {
        
        self.context = context
        localDB = LocalDBService(context: context)
        
        let coreDataItems = localDB.fetchAllListFromDB()
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

        
        localDB.save()
        let lists = localDB.fetchAllListFromDB()
        coreDataItemsCombine.send(lists)
    }

    func saveNewListToDB(listName: String) {
        
        localDB.saveNewListToDB(listName: listName)
        
        let lists = localDB.fetchAllListFromDB()
        coreDataItemsCombine.send(lists)
    }

    func deleteListFromDB(item: List) {

        localDB.deleteListFromDB(list: item)
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
