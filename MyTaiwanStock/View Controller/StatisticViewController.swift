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
    var viewModel:StatisticViewModel!
    var subscription = Set<AnyCancellable>()

    @IBOutlet weak var pieChartView: PieChartView!

    @IBOutlet weak var segment: UISegmentedControl!
    var scrollView = UIScrollView()
    let stackView = UIStackView()
    var tableView1: UITableView! = UITableView() //庫存
    var tableView2: UITableView! = UITableView() //股利
    
    @IBAction func tapSegment(_ sender: UISegmentedControl) {
       
        switch sender.selectedSegmentIndex {
        case 0:
            scrollView.contentOffset.x = 0
        case 1:
            scrollView.contentOffset.x = view.frame.width
        default:
            break
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pieChartView.delegate = self

        viewModel = StatisticViewModel()
        bindViewModel()
        
        setupLayout()
        
    }
    
    override func viewWillAppear(_ animated: Bool) {

        viewModel.fetchData(to: pieChartView)
        viewModel.fetchDividendAndClassify()
        
        
    }
    
    func setupLayout() {
        scrollView.addSubview(stackView)
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: 0),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, multiplier: 2.0)
        ])
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.contentSize = CGSize(width: view.frame.size.width*2.0, height: scrollView.frame.height)
        scrollView.isPagingEnabled = true
        
        tableView1.tag = 1

        tableView2.tag = 2
        stackView.addArrangedSubview(tableView1)
        stackView.addArrangedSubview(tableView2)
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        
        tableView1.dataSource = self
        tableView2.dataSource = self
        tableView2.delegate = self
        
        tableView1.register(UINib(nibName: "StatisticStockTableViewCell", bundle: nil), forCellReuseIdentifier: StatisticStockTableViewCell.identifier)
        tableView1.rowHeight = 90
        tableView1.separatorStyle = .none
        
        tableView2.register(UINib(nibName: "StatisticDividendTableViewCell", bundle: nil), forCellReuseIdentifier: StatisticDividendTableViewCell.identifier)
        tableView2.rowHeight = 90
        tableView2.separatorStyle = .none
    }
   
    func bindViewModel() {

        viewModel.stockNoToAssetCombine
            .combineLatest(viewModel.isLoading)
            .sink(receiveValue: { [weak self] (data, isLoading) in
                
                print("data \(data) isLoading \(isLoading)")
                self?.tableView1.reloadData()
                if data.isEmpty && !isLoading {
                    self?.showWarningPopup()
                }
            })
            .store(in: &subscription)
        
        viewModel.classifiedDividendCombine
            .sink(receiveValue: { [weak self] data in
                self?.tableView2.reloadData()
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
        if(tableView.tag == 2) {
            return viewModel.classifiedDividendCombine.value.count
        }
        if(tableView.tag == 1) {
            return viewModel.stockNoToAssetCombine.value.count
        }
        return 0
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if(tableView.tag == 2) {
            let cell = tableView.dequeueReusableCell(withIdentifier: StatisticDividendTableViewCell.identifier, for: indexPath) as! StatisticDividendTableViewCell
            cell.update(with: viewModel.classifiedDividendCombine.value[indexPath.row])
            cell.selectionStyle = .none
            return cell
        }
        if(tableView.tag == 1) {
            let cell = tableView.dequeueReusableCell(withIdentifier: StatisticStockTableViewCell.identifier, for: indexPath) as! StatisticStockTableViewCell
            let stockNoToAsset = viewModel.stockNoToAssetCombine.value[indexPath.row]
            cell.update(with: stockNoToAsset)
            cell.selectionStyle = .none
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(tableView.tag==2){

            let vc = DividendDetailViewController(stockNo: viewModel.classifiedDividendCombine.value[indexPath.row].stockNo)
            
            present(vc, animated: true, completion: nil)
            
        }
    }
}
