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
    
    /// Page the scroll view is on (0 inventory, 1 dividend). A resize changes the page width, so the
    /// offset is rebuilt from this instead of being read back from the old offset, which UIKit may
    /// already have clamped to the old content size.
    private var currentPage = 0
    private var alignedPageWidth: CGFloat = 0

    @IBAction func tapSegment(_ sender: UISegmentedControl) {

        switch sender.selectedSegmentIndex {
        case 0, 1:
            currentPage = sender.selectedSegmentIndex
            scrollView.contentOffset.x = CGFloat(currentPage) * scrollView.bounds.width
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Keep the current page in view when the page width changes (scene resized or rotated).
        let width = scrollView.bounds.width
        guard abs(width - alignedPageWidth) > 0.5 else { return }
        alignedPageWidth = width
        scrollView.contentOffset.x = CGFloat(currentPage) * width
    }
    
    func setupLayout() {
        scrollView.addSubview(stackView)
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 10),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            // Two pages side by side. The content guide gives the scroll view its content size, so it
            // follows the page size whenever the scene resizes.
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, multiplier: 2.0)
        ])
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.isPagingEnabled = true
        scrollView.delegate = self

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

// The dividend table also uses this controller as its delegate, so every handler checks which scroll view called.
extension StatisticViewController {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        updateCurrentPage(from: scrollView)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            updateCurrentPage(from: scrollView)
        }
    }

    private func updateCurrentPage(from scrollView: UIScrollView) {
        guard scrollView === self.scrollView, scrollView.bounds.width > 0 else { return }
        currentPage = min(max(Int((scrollView.contentOffset.x / scrollView.bounds.width).rounded()), 0), 1)
    }
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
