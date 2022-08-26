//
//  AddListViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/4/15.
//
import Combine
import CoreData
import UIKit
import Charts

class AddListViewController: UIViewController {
    var subscription = Set<AnyCancellable>()

    let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    var viewModel: AddListViewModel!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addButton: UIButton!
    @IBAction func clickAddButton() {
        let alertVC = UIAlertController(title: "新增收藏清單", message: nil, preferredStyle: .alert)
        alertVC.addTextField { textField in
            textField.placeholder = "清單名稱"
            textField.keyboardType = .default
        }
        let okAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            // save to core data
            guard let newListName = alertVC.textFields?[0].text else {return}
            
            self?.viewModel.saveNewListToDB(listName: newListName)
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
        viewModel = AddListViewModel(context: context)

        addButton.layer.cornerRadius = 5
        
        bindViewModel()
        
        initView()
        
    }
    func bindViewModel() {
        
        
        viewModel.listNamesCombine
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &subscription)
    }
    
    func initView() {
        tableView.separatorStyle = .none
        tableView.backgroundColor = .secondarySystemBackground
    }

}


extension AddListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "listNameCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = viewModel.listNamesCombine.value[indexPath.row]
        
        cell.contentConfiguration = content
        cell.backgroundColor = .systemBackground
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.listNamesCombine.value.count
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
            
            viewModel.deleteList(at: index)
        }
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    // update list name
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        let originalListName = self.viewModel.listNamesCombine.value[indexPath.row]
        
        let alertVC = UIAlertController(title: "編輯清單名稱", message: nil, preferredStyle: .alert)
        alertVC.addTextField { textField in
            
            textField.keyboardType = .default
            textField.text = originalListName
        }
        let okAction = UIAlertAction(title: "Save", style: .default) { _ in
            // save to core data
            guard let newListName = alertVC.textFields?[0].text else {return}

            self.viewModel.updateListName(at: indexPath.row, with: newListName)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // cancel
        }
        alertVC.addAction(okAction)
        alertVC.addAction(cancelAction)
        self.present(alertVC, animated: true, completion: nil)
    }
}
