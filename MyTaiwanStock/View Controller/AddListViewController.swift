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

    var viewModel: AddListViewModel!
    
    @IBOutlet weak var tableView: UITableView!

    let floatingButton: UIButton = {
       let button = UIButton()
        button.setImage(UIImage(systemName: "plus",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)),
                        for: .normal)
        button.backgroundColor = .black
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.layer.shadowColor = UIColor.label.cgColor
        button.layer.shadowOpacity = 0.5
        button.layer.shadowOffset = CGSize(width: 5, height: 5)
        button.layer.shadowRadius = 10
        button.setTitle(nil, for: .normal)
        button.addTarget(self, action: #selector(tapFabButton), for: .touchUpInside)
        return button
    }()

    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        navigationItem.title = "編輯收藏清單"
        navigationItem.rightBarButtonItem = editButtonItem
        viewModel = AddListViewModel()
        
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
        view.addSubview(floatingButton)
        floatingButton.addTarget(self, action: #selector(tapFabButton), for: .touchUpInside)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        floatingButton.frame = CGRect(x: view.frame.width - 80,
                                      y: view.frame.height - 80 - view.safeAreaInsets.bottom,
                                      width: 50, height: 50)
    }

    @objc func tapFabButton() {
        let alertVC = UIAlertController(title: "新增收藏清單", message: nil, preferredStyle: .alert)
        alertVC.addTextField { textField in
            textField.placeholder = "清單名稱"
            textField.keyboardType = .default
        }
        let okAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            // save to core data
            guard let newListName = alertVC.textFields?[0].text else {return}
            
            self?.viewModel.saveNewList(listName: newListName)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // cancel
        }
        alertVC.addAction(okAction)
        alertVC.addAction(cancelAction)
        self.present(alertVC, animated: true, completion: nil)
    }
}


extension AddListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
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
