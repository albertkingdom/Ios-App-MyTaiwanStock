//
//  AddListViewModel.swift
//  MyTaiwanStock
//
//  Created by 林煜凱 on 5/16/22.
//

import Foundation
import CoreData

class AddListViewModel {
    var listNames = Observable<[String]>([])
    var coreDataItems: [List]! {
        didSet {
            self.listNames.value = coreDataItems.map({ list in
                list.name!
            })
        }
    }
    var context: NSManagedObjectContext!
    
   
    //
    func deleteList(at index:Int) {
        let deleteItem = self.coreDataItems[index]
        deleteListFromDB(item: deleteItem)
        self.coreDataItems.remove(at: index)
    }
    //
    func updateListName(at index: Int, with newName: String) {
        let listToBeUpdate = self.coreDataItems[index]
        listToBeUpdate.name = newName
        self.updateList(item: listToBeUpdate)
    }
    // MARK: CORE DATA
    func saveNewListToDB(listName: String) {
        
        let newList = List(context: context)
        newList.name = listName
        do {
            try context.save()
            self.fetchAllListFromDB()
         
        } catch {
            print("error, \(error.localizedDescription)")
        }
        
    }
    func fetchAllListFromDB() {
        let fetchRequest: NSFetchRequest<List> = List.fetchRequest()
        do {
            self.coreDataItems = try context.fetch(fetchRequest)
            //print("lists \(self.coreDataItems)")
            
            
            
        } catch let error {
            print(error.localizedDescription)
        }
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
            fetchAllListFromDB()
        } catch {
            print("error, \(error.localizedDescription)")
        }
    }
}
