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
    
    let repository = RepositoryImpl()
    
    init() {
        
        let coreDataItems = repository.stockList()
        coreDataItemsCombine.send(coreDataItems)
        
        
        coreDataItemsCombine.sink { [weak self] list in
            let listNames = list.map({ list in
                list.name!
            })
            self?.listNamesCombine.send(listNames)
            
        }
        .store(in: &subscription)
    }
   
    //
    func deleteList(at index:Int) {
        let deleteItem = self.coreDataItemsCombine.value[index]

        self.coreDataItemsCombine.value.remove(at: index)
        
        repository.deleteList(list: deleteItem)
    }
    //
    func updateListName(at index: Int, with newName: String) {
        let listToBeUpdate = self.coreDataItemsCombine.value[index]
        listToBeUpdate.name = newName

        repository.localDBService.saveContext()
        
        let lists = repository.stockList()
        coreDataItemsCombine.send(lists)
    }
    
    func saveNewList(listName: String) {
        let _ = repository.saveList(with: listName)
        let lists = repository.stockList()
        coreDataItemsCombine.send(lists)
    }


    func getLoginAccountEmail() -> String? {
        guard let email = Auth.auth().currentUser?.email else {return nil}
        return email
    }

}
