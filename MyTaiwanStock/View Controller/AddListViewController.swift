//
//  AddListViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/4/15.
//
import CoreData
import UIKit
import Charts

class AddListViewController: UIViewController {
    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var coreDataItems: [List]! {
        didSet {
            self.listsNames = coreDataItems.map({ list in
                list.name!
            })
        }
    }
    var listsNames:[String] = [] {
        didSet {
            print("didset listsNames \(listsNames)")
            tableView.reloadData()
        }
    }
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIButton!
    @IBAction func clickAddButton() {
        let alertVC = UIAlertController(title: "編輯收藏清單", message: nil, preferredStyle: .alert)
        alertVC.addTextField { textField in
            textField.placeholder = "清單名稱"
            textField.keyboardType = .default
        }
        let okAction = UIAlertAction(title: "Save", style: .default) { _ in
            // save to core data
            guard let newListName = alertVC.textFields?[0].text else {return}
            
            self.saveNewListToDB(listName: newListName)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // cancel
        }
        alertVC.addAction(okAction)
        alertVC.addAction(cancelAction)
        self.present(alertVC, animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        navigationItem.rightBarButtonItem = editButtonItem
        fetchAllListFromDB()
        //  fetch all list in db
    }
    
    
    

}
extension AddListViewController {
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
            print("lists \(self.coreDataItems)")
            
            
            
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

extension AddListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "listNameCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = listsNames[indexPath.row]
        
        cell.contentConfiguration = content
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listsNames.count
    }
    
}

extension AddListViewController: UITableViewDelegate {
    override func setEditing(_ editing: Bool, animated: Bool) {
        tableView.setEditing(editing, animated: true)
        super.setEditing(editing, animated: true)
    }
    // detele List
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let index = indexPath.row
      
        if editingStyle == .delete {

            let deleteItem = self.coreDataItems[indexPath.row]
            deleteListFromDB(item: deleteItem)
            self.coreDataItems.remove(at: indexPath.row)
                        
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    // update list name
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let listToBeUpdate = self.coreDataItems[indexPath.row]
        let originalListName = self.listsNames[indexPath.row]
        
        let alertVC = UIAlertController(title: "編輯清單名稱", message: nil, preferredStyle: .alert)
        alertVC.addTextField { textField in
            
            textField.keyboardType = .default
            textField.text = originalListName
        }
        let okAction = UIAlertAction(title: "Save", style: .default) { _ in
            // save to core data
            guard let newListName = alertVC.textFields?[0].text else {return}
            listToBeUpdate.name = newListName
            self.updateList(item: listToBeUpdate)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // cancel
        }
        alertVC.addAction(okAction)
        alertVC.addAction(cancelAction)
        self.present(alertVC, animated: true, completion: nil)
    }
}
