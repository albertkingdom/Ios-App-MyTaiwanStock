//
//  DividendDetailViewController.swift
//  MyTaiwanStock
//
//  Created by YKLin on 12/24/22.
//

import UIKit
import Combine

class DividendDetailViewController: UIViewController {
    var tableView: UITableView!
    let viewModel = StatisticViewModel()
    var subscription = Set<AnyCancellable>()
    var stockNo: String
    
    init(stockNo: String) {
        self.stockNo = stockNo
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        // init from storyboard
        self.stockNo = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        setupLayout()
        bindViewModel()
        viewModel.fetchDividend(with: stockNo)
        
        title = "Test"
    }
    
    func setupLayout(){
        tableView = UITableView(frame: .zero)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        tableView.register(UINib(nibName: "DividendDetailTableViewCell", bundle: nil), forCellReuseIdentifier: DividendDetailTableViewCell.identifier)
        tableView.dataSource = self
        tableView.rowHeight = 120

    }

    func bindViewModel() {
        viewModel.allDividendsCombine
            .sink { [weak self] list in
                self?.tableView.reloadData()
            }
            .store(in: &subscription)
    }
    
}

extension DividendDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.allDividendsCombine.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DividendDetailTableViewCell.identifier, for: indexPath) as! DividendDetailTableViewCell
        cell.update(with: viewModel.allDividendsCombine.value[indexPath.row])
        cell.selectionStyle = .none
        return cell
    }
}
