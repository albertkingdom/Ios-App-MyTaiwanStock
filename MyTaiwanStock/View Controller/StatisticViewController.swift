//
//  StatisticViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2022/1/5.
//
import CoreData
import Charts
import UIKit
import Combine

class StatisticViewController: UIViewController {
    let viewModel = StatisticViewModel()
    var subscription = Set<AnyCancellable>()

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
        
        initView()
    }
    
    override func viewWillAppear(_ animated: Bool) {

        viewModel.fetchData(to: pieChartView)
        
    }
    func initView() {
        tableView.backgroundColor = .secondarySystemBackground
        tableView.separatorStyle = .none
    }
    func bindViewModel() {

        viewModel.stockNoToAssetCombine
            .combineLatest(viewModel.isLoading)
            .sink(receiveValue: { [weak self] (data, isLoading) in
                
                print("data \(data) isLoading \(isLoading)")
                self?.tableView.reloadData()
                if data.isEmpty && !isLoading {
                    self?.showWarningPopup()
                }
            })
            .store(in: &subscription)
        

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

        return viewModel.stockNoToAssetCombine.value.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "statisticCell", for: indexPath) as! StatisticTableViewCell

        let stockNoToAsset = viewModel.stockNoToAssetCombine.value[indexPath.row]
        cell.update(with: stockNoToAsset)
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50
    }
}
