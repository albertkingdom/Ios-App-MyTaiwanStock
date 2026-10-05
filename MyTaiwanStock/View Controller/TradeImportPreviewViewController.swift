//
//  TradeImportPreviewViewController.swift
//  MyTaiwanStock
//

import UIKit

/// Shows every trade recognized from the screenshots before anything is written. The user picks
/// the trades to import, fixes values, and chooses the list the stocks are added to.
final class TradeImportPreviewViewController: UIViewController {
    private let viewModel: TradeImportViewModel
    private let onImported: () -> Void

    private let listButton = UIButton(type: .system)
    private let noticeLabel = UILabel()
    private let summaryLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let importButton = UIButton(type: .system)

    init(viewModel: TradeImportViewModel, onImported: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onImported = onImported
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "確認匯入"
        view.backgroundColor = .systemBackground
        setUpViews()
        refresh()
    }

    // MARK: layout

    private func setUpViews() {
        listButton.contentHorizontalAlignment = .leading
        listButton.showsMenuAsPrimaryAction = true

        noticeLabel.font = .preferredFont(forTextStyle: .footnote)
        noticeLabel.textColor = .systemOrange
        noticeLabel.numberOfLines = 0
        noticeLabel.text = "選擇「不加入清單」時，匯入的買賣紀錄無法從首頁進入該股票的詳細頁查看。"

        summaryLabel.font = .preferredFont(forTextStyle: .footnote)
        summaryLabel.textColor = .secondaryLabel

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "trade")

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .large
        importButton.configuration = configuration
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [listButton, noticeLabel, summaryLabel])
        header.axis = .vertical
        header.spacing = 6
        header.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        header.isLayoutMarginsRelativeArrangement = true

        let root = UIStackView(arrangedSubviews: [header, tableView, importButton])
        root.axis = .vertical
        root.spacing = 8
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            importButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func refresh() {
        let listTitle = viewModel.selectedListName ?? "不加入清單"
        listButton.setTitle("加入清單：\(listTitle) ▾", for: .normal)
        listButton.menu = UIMenu(children: viewModel.selectableLists.map { name in
            UIAction(
                title: name ?? "不加入清單",
                state: name == viewModel.selectedListName ? .on : .off
            ) { [weak self] _ in
                self?.viewModel.selectList(name)
                self?.refresh()
            }
        })
        noticeLabel.isHidden = !viewModel.showsNoListNotice

        let counts = Dictionary(grouping: viewModel.items, by: \.status).mapValues(\.count)
        summaryLabel.text = "辨識 \(viewModel.items.count) 筆　可匯入 \(counts[.importable] ?? 0)　重複 \(counts[.duplicate] ?? 0)　"
            + "需補資料 \(counts[.incomplete] ?? 0)　不支援 \(counts[.unsupported] ?? 0)"

        let selected = viewModel.items.filter(\.isSelected).count
        importButton.configuration?.title = "匯入 \(selected) 筆"
        importButton.isEnabled = viewModel.isImportEnabled
        tableView.reloadData()
    }

    // MARK: actions

    @objc private func importTapped() {
        do {
            let submitted = try viewModel.confirmImport()
            let alert = UIAlertController(title: "已匯入 \(submitted) 筆買賣紀錄", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default) { [weak self] _ in self?.onImported() })
            present(alert, animated: true)
        } catch {
            let alert = UIAlertController(
                title: "無法匯入", message: "有成交紀錄的資料不完整或不正確，請修正後再試。", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .default))
            present(alert, animated: true)
            refresh()
        }
    }

    private func presentEditor(for item: TradePreviewItem) {
        let editor = TradeEditViewController(item: item) { [weak self] stockNo, price, amount, date, side in
            guard let self else { return }
            viewModel.setStockNo(stockNo, for: item.id)
            viewModel.setPrice(price, for: item.id)
            viewModel.setAmount(amount, for: item.id)
            viewModel.setDate(date, for: item.id)
            viewModel.setSide(side, for: item.id)
            refresh()
        }
        navigationController?.pushViewController(editor, animated: true)
    }

    // MARK: row text

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = TaipeiCalendar.timeZone
        return formatter
    }()

    private static func statusText(_ status: TradePreviewStatus) -> String {
        switch status {
        case .importable: return ""
        case .duplicate: return "重複"
        case .incomplete: return "需補資料"
        case .unsupported: return "不支援"
        }
    }
}

extension TradeImportPreviewViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        viewModel.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = viewModel.items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "trade", for: indexPath)

        var content = UIListContentConfiguration.subtitleCell()
        let code = item.stockNo ?? "？？？"
        let side = item.side == .buy ? "買" : "賣"
        let status = Self.statusText(item.status)
        content.text = "\(code) \(item.stockName)　\(side)" + (status.isEmpty ? "" : "　【\(status)】")
        let date = item.date.map(Self.dateFormatter.string(from:)) ?? "日期？"
        let amount = item.amount.map { "\($0) 股" } ?? "股數？"
        let price = item.price.map { String(format: "%.2f", $0) } ?? "價格？"
        content.secondaryText = "\(date) · \(amount) · \(price)"
        let selectable = item.status == .importable || item.status == .duplicate
        content.image = UIImage(systemName: item.isSelected ? "checkmark.square.fill" : (selectable ? "square" : "exclamationmark.triangle"))
        content.imageProperties.tintColor = selectable ? .systemBlue : .systemRed
        cell.contentConfiguration = content

        switch item.status {
        case .incomplete, .unsupported:
            cell.backgroundColor = UIColor.systemRed.withAlphaComponent(0.12)
        case .duplicate:
            cell.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.15)
        case .importable:
            cell.backgroundColor = .systemBackground
        }

        let edit = UIButton(type: .system)
        edit.setImage(UIImage(systemName: "pencil"), for: .normal)
        edit.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        edit.addAction(UIAction { [weak self] _ in self?.presentEditor(for: item) }, for: .touchUpInside)
        edit.isEnabled = item.status != .unsupported
        cell.accessoryView = edit
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        viewModel.toggleSelection(id: viewModel.items[indexPath.row].id)
        refresh()
    }
}
