//
//  StockViewController.swift
//  MyTaiwanStock
//
//  Created by Albert Lin on 2021/10/4.
//
import CoreData
import UIKit
import Charts
import FirebaseFirestore

class StockViewController: UIViewController {
    var chartService: ChartService!
    var context: NSManagedObjectContext?
    lazy var fetchedResultsController: NSFetchedResultsController<InvestHistory> = {
    
        let fetchRequest: NSFetchRequest<InvestHistory> = InvestHistory.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "stockNo", ascending: false)
        let predicate = NSPredicate(format: "stockNo == %@", self.stockNo!)
        fetchRequest.sortDescriptors = [sortDescriptor]
        fetchRequest.predicate = predicate
        let frc = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context!, sectionNameKeyPath: nil, cacheName: nil)
        frc.delegate = self
        return frc
    }()
    

    @IBOutlet weak var combinedChartView: CombinedChartView!
    var stockInfoForCandleStickChart: [[String]]!
    var stockNo: String!
    var stockName: String!
    var stockPrice: String!
    private let database = Firestore.firestore()
    private var channelID: String?
    var isHideKplot: Bool = false {
        didSet {
            if !isHideKplot {
                kplotHeight.constant = 300
                
                showOrHideButton.setImage(UIImage(systemName: "arrow.up.to.line"), for: .normal)
            } else {
                kplotHeight.constant = 0
                showOrHideButton.setImage(UIImage(systemName: "arrow.down.to.line"), for: .normal)
            }
            UIView.animate(withDuration: 0.5) {
                self.view.layoutIfNeeded()
            }
            
        }
    }
    @IBOutlet weak var dateView: UILabel!
    @IBOutlet weak var openPriceView: UILabel!
    @IBOutlet weak var closePriceView: UILabel!
    @IBOutlet weak var highPriceView: UILabel!
    @IBOutlet weak var lowPriceView: UILabel!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var kplotHeight: NSLayoutConstraint!
    @IBOutlet weak var showOrHideButton: UIButton!
    @IBAction func touchHideKplotButton(_ sender: Any) {
       
        isHideKplot = !isHideKplot

      
    }
    @IBOutlet weak var historyContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        combinedChartView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView() // remove unused separator

        navigationItem.title = stockNo
       
        let newsButton = UIBarButtonItem(title: "News", style: .plain, target: self, action: #selector(navigateToNews))
        let addHistoryButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(navigateToAddRecord))
        let chatRoomButton = UIBarButtonItem(image: UIImage(systemName: "message"), style: .plain, target: self, action: #selector(navigateToChatRoom))
        navigationItem.rightBarButtonItems = [addHistoryButton, newsButton, chatRoomButton]
        
        
        checkIsExistingChannel()


    }
 
    @objc func navigateToAddRecord() {
        let destinationController = storyboard?.instantiateViewController(withIdentifier: "addRecordController") as! AddHistoryViewController
        destinationController.stockNo = self.stockNo
        destinationController.context = self.context
        navigationController?.pushViewController(destinationController, animated: true)
    }
    @objc func navigateToNews() {
        let destinationController = storyboard?.instantiateViewController(withIdentifier: "newsListVC") as! NewsListViewController
        destinationController.stockName = self.stockName
        
        navigationController?.pushViewController(destinationController, animated: true)
    }
    @objc func navigateToChatRoom() {

        if let id = channelID {
            let chatRoomVC = ChatViewController(channelName: "\(stockNo!) chat room", channelId: id)
            navigationController?.pushViewController(chatRoomVC, animated: true)
        }
    }
    override func viewWillAppear(_ animated: Bool) {
      
        print("stockview viewwillappear")
    
        StockInfo.fetchTwoMonth(stockNo: stockNo) { data in
            self.stockInfoForCandleStickChart = data
            DispatchQueue.main.async {
                
                if self.stockInfoForCandleStickChart != nil{
//                    self.prepareForChart()
                    self.chartService = ChartService(candleStickData: self.stockInfoForCandleStickChart, stockNo: self.stockNo)
                    self.chartService.prepareForCombinedChart(combinedChartView: self.combinedChartView)
                }
            }
        }
        
        do {
            try fetchedResultsController.performFetch()
            //tableView.reloadData()
        } catch {
            fatalError("Invest history fetch error")
        }
    }
    
   
    
}


extension StockViewController: ChartViewDelegate {
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {

        
        let index = Int(highlight.x)
        dateView.text = "日期：\(stockInfoForCandleStickChart[index][0])"
        openPriceView.text = "開盤：\(stockInfoForCandleStickChart[index][3])"
        closePriceView.text = "收盤：\(stockInfoForCandleStickChart[index][6])"
        highPriceView.text = "最高：\(stockInfoForCandleStickChart[index][4])"
        lowPriceView.text = "最低：\(stockInfoForCandleStickChart[index][5])"
        
    }

}


extension StockViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return history.count
        guard let sectionInfo = fetchedResultsController.sections?[section] else { return 0 }

        return sectionInfo.numberOfObjects
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath) as! HistoryTableViewCell
        let cellcontent = fetchedResultsController.object(at: indexPath)
        
        cell.update(with: cellcontent, stockPrice: stockPrice)

        return cell
    }
    
    // MARK: click table cell to highlight on chart
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
      

        // click record to highlight corresponding value on candlestick chart
        // get date of click record
        if let date = fetchedResultsController.object(at: indexPath).date {
          
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "zh_TW")
            dateFormatter.setLocalizedDateFormatFromTemplate("yyyy/MM/dd")
           
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day], from: date)

            if var year = components.year, let month = components.month, let day = components.day {
                // convert date to following format like:  111/03/18
                year = year - 1911
                let fullMonth = month > 9 ? "month" : "0\(month)"
                let targetDateString = "\(year)/\(fullMonth)/\(day)"

                stockInfoForCandleStickChart.enumerated().forEach { index, candleData in
                    // find the index of date in stockInfoForCandleStickChart
                    if candleData[0] == targetDateString {

                        combinedChartView.highlightValue(x: Double(index), dataSetIndex: 0, dataIndex: 1)
                        combinedChartView.layoutIfNeeded()
                    }
                }
                
            }
        }
        
       
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: true)
        tableView.setEditing(editing, animated: true)
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            
            
            let objectToDelete = fetchedResultsController.object(at: indexPath)
            context?.delete(objectToDelete)
            do {
                try context?.save()
            } catch {
                fatalError("\(error.localizedDescription)")
            }
        }
    }
}

extension StockViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        guard let _ = anObject as? InvestHistory else {
            return
        }
        
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case .delete:
            guard let indexPathToDel = indexPath else { return }
            tableView.deleteRows(at: [indexPathToDel], with: .automatic)
        default:
            return
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

// MARK: chat room channel
extension StockViewController {

    private var channelReference: CollectionReference {
      return database.collection("channels")
    }
    private func createChannel(){
        guard
            let channelName = stockNo
        else {
            return
        }
        
        
        let documentRef = channelReference.addDocument(data: ["name": channelName]) { error in
            if let error = error {
                print("Error saving channel: \(error.localizedDescription)")
            }
        }
        channelID = documentRef.documentID
        
    }
    func checkIsExistingChannel() {
        var isExisting = false
        guard let channelName = stockNo
        else {
            return
        }
        channelReference.whereField("name", isEqualTo: channelName).getDocuments { (snapshot, err) in
            if let err = err {
                print("Error getting documents: \(err)")
                
            } else {
                for document in snapshot!.documents {
                    print("\(document.documentID) => \(document.data())")
                    
                }
                
          
                if (snapshot!.documents.count > 0) {
                    isExisting = true
                    self.channelID = snapshot?.documents[0].documentID
                    return
                }
                self.createChannel()
            }
        }
        
        
    }
}
