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

enum ListNameError: LocalizedError, Equatable {
    case empty
    case duplicate

    var errorDescription: String? {
        switch self {
        case .empty: return "清單名稱不可空白"
        case .duplicate: return "清單名稱已存在"
        }
    }
}

class AddListViewModel {
    var subscription = Set<AnyCancellable>()

    var listNamesCombine = CurrentValueSubject<[String],Never>([])

    var coreDataItemsCombine = CurrentValueSubject<[ListStruct],Never>([])
    
    let repository: NetworkServiceImpl

    init(repository: NetworkServiceImpl = NetworkServiceImpl()) {
        self.repository = repository
        
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
    func updateListName(at index: Int, with newName: String) throws {
        let oldName = listNamesCombine.value[index]
        let name = try validatedListName(newName, currentName: oldName)
        guard name != oldName else { return }

        repository.updateListName(newName: name, oldName: oldName)

        let lists = repository.stockList()
        coreDataItemsCombine.send(lists)
    }
    
    func saveNewList(listName: String) throws {
        let name = try validatedListName(listName)
        let _ = repository.saveList(with: name)
        let lists = repository.stockList()
        coreDataItemsCombine.send(lists)
    }

    /// 去除前後空白，並拒絕空白名稱與其他清單已使用的名稱
    private func validatedListName(_ name: String, currentName: String? = nil) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ListNameError.empty }
        if trimmed != currentName && listNamesCombine.value.contains(trimmed) {
            throw ListNameError.duplicate
        }
        return trimmed
    }


    func getLoginAccountEmail() -> String? {
        guard let email = Auth.auth().currentUser?.email else {return nil}
        return email
    }

}
