//
//  StatisticViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/1/5.
//
import CoreData
import Charts
import UIKit

class StatisticViewController: UIViewController {
    let viewModel = StatisticViewModel()


    @IBOutlet weak var pieChartView: PieChartView!
    @IBOutlet weak var tableView: UITableView!
    var context: NSManagedObjectContext?

    override func viewDidLoad() {
        super.viewDidLoad()
        pieChartView.delegate = self
        tableView.dataSource = self
        tableView.delegate = self

        viewModel.context = context
        bindViewModel()
    }
    
    override func viewWillAppear(_ animated: Bool) {

        viewModel.fetchData(to: pieChartView)
    }
    func bindViewModel() {
        viewModel.stockNoToAsset.bind { [weak self] _ in
            self?.tableView.reloadData()
        }
        viewModel.isEmptyData.bind { [weak self] isEmpty in
            if let isEmpty = isEmpty, isEmpty {
                self?.showWarningPopup()
            }
        }
    }
    func showWarningPopup() {

        let alertVC = UIAlertController(title: "Remind", message: "Please add some invest history!", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) { _ in
            self.tabBarController?.selectedIndex = 0
        }
        alertVC.addAction(okAction)
        self.present(alertVC, animated: true, completion: nil)
    }
 
    
}

extension StatisticViewController: ChartViewDelegate {
    
}

extension StatisticViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.stockNoToAsset.value?.count ?? 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "statisticCell", for: indexPath) as! StatisticTableViewCell
        guard let stockNoToAsset = viewModel.stockNoToAsset.value?[indexPath.row] else { return UITableViewCell() }
        cell.update(with: stockNoToAsset)
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}
