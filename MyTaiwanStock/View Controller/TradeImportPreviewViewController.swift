//
//  TradeImportPreviewViewController.swift
//  MyTaiwanStock
//

import UIKit

/// Shows every trade recognized from the screenshots before anything is written. The user picks
/// the trades to import, fixes values, and chooses the list the stocks are added to.
final class TradeImportPreviewViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case list
        case trades
    }

    private let viewModel: TradeImportViewModel
    private let onImported: () -> Void

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
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
        view.backgroundColor = .systemGroupedBackground
        setUpViews()
        refresh()
    }

    // MARK: layout

    private func setUpViews() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 24, bottom: 14, trailing: 24)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline)
            return attributes
        }
        importButton.configuration = configuration
        importButton.addTarget(self, action: #selector(importTapped), for: .touchUpInside)

        // The button is inset from the screen edges and kept clear of the floating tab bar.
        let buttonBar = UIView()
        buttonBar.backgroundColor = .systemGroupedBackground
        importButton.translatesAutoresizingMaskIntoConstraints = false
        buttonBar.addSubview(importButton)
        NSLayoutConstraint.activate([
            importButton.topAnchor.constraint(equalTo: buttonBar.topAnchor, constant: 8),
            importButton.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor, constant: 20),
            importButton.trailingAnchor.constraint(equalTo: buttonBar.trailingAnchor, constant: -20),
            importButton.bottomAnchor.constraint(equalTo: buttonBar.bottomAnchor, constant: -88),
            importButton.heightAnchor.constraint(equalToConstant: 52),
        ])

        let root = UIStackView(arrangedSubviews: [tableView, buttonBar])
        root.axis = .vertical
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func refresh() {
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

    // MARK: row content

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        formatter.timeZone = TaipeiCalendar.timeZone
        return formatter
    }()

    private static func statusText(_ status: TradePreviewStatus) -> String? {
        switch status {
        case .importable: return nil
        case .duplicate: return "重複"
        case .incomplete: return "需補資料"
        case .unsupported: return "不支援"
        }
    }

    private static func statusColor(_ status: TradePreviewStatus) -> UIColor {
        status == .duplicate ? .systemOrange : .systemRed
    }

    private func listPickerButton() -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.title = viewModel.selectedListName ?? "不加入清單"
        configuration.image = UIImage(systemName: "chevron.up.chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(scale: .small)
        let button = UIButton(configuration: configuration)
        button.menu = UIMenu(children: viewModel.selectableLists.map { name in
            UIAction(title: name ?? "不加入清單", state: name == viewModel.selectedListName ? .on : .off) { [weak self] _ in
                self?.viewModel.selectList(name)
                self?.refresh()
            }
        })
        button.showsMenuAsPrimaryAction = true
        return button
    }

    /// A table cell's accessory view is laid out by frame, so give it its natural size.
    private func fitted(_ view: UIView) -> UIView {
        view.frame.size = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return view
    }

    private func summaryText() -> String {
        let counts = Dictionary(grouping: viewModel.items, by: \.status).mapValues(\.count)
        var parts = ["可匯入 \(counts[.importable] ?? 0)"]
        if let duplicates = counts[.duplicate] { parts.append("重複 \(duplicates)") }
        if let incomplete = counts[.incomplete] { parts.append("需補資料 \(incomplete)") }
        if let unsupported = counts[.unsupported] { parts.append("不支援 \(unsupported)") }
        return parts.joined(separator: "　")
    }
}

extension TradeImportPreviewViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .list ? 1 : viewModel.items.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Section(rawValue: section) == .trades ? "辨識到 \(viewModel.items.count) 筆成交紀錄" : nil
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .list:
            return viewModel.showsNoListNotice ? "選擇「不加入清單」時，匯入的買賣紀錄無法從首頁進入該股票的詳細頁查看。" : nil
        case .trades:
            return summaryText()
        case nil:
            return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.accessoryView = nil

        if Section(rawValue: indexPath.section) == .list {
            var content = cell.defaultContentConfiguration()
            content.text = "加入清單"
            cell.contentConfiguration = content
            cell.accessoryView = fitted(listPickerButton())
            cell.selectionStyle = .none
            return cell
        }

        let item = viewModel.items[indexPath.row]
        let selectable = item.status == .importable || item.status == .duplicate

        var content = UIListContentConfiguration.subtitleCell()
        content.text = [item.stockName, item.stockNo].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "　")
        if content.text?.isEmpty ?? true { content.text = "未辨識" }
        if item.stockNo == nil { content.text = (content.text ?? "") + "　股號？" }
        let side = item.side == .buy ? "買" : "賣"
        let date = item.date.map(Self.dateFormatter.string(from:)) ?? "日期？"
        let amount = item.amount.map { "\($0) 股" } ?? "股數？"
        let price = item.price.map { String(format: "%.2f", $0) } ?? "價格？"
        content.secondaryText = "\(side) ・ \(amount) ・ \(price) ・ \(date)"
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: item.isSelected ? "checkmark.circle.fill" : (selectable ? "circle" : "exclamationmark.circle"))
        content.imageProperties.tintColor = item.isSelected ? .systemBlue : (selectable ? .tertiaryLabel : Self.statusColor(item.status))
        cell.contentConfiguration = content

        var accessoryViews: [UIView] = []
        if let text = Self.statusText(item.status) {
            let label = UILabel()
            label.text = text
            label.font = .preferredFont(forTextStyle: .footnote)
            label.textColor = Self.statusColor(item.status)
            accessoryViews.append(label)
        }
        if item.status != .unsupported {
            let info = UIButton(type: .system)
            info.setImage(UIImage(systemName: "info.circle"), for: .normal)
            info.addAction(UIAction { [weak self] _ in self?.presentEditor(for: item) }, for: .touchUpInside)
            accessoryViews.append(info)
        }
        let stack = UIStackView(arrangedSubviews: accessoryViews)
        stack.spacing = 10
        stack.alignment = .center
        cell.accessoryView = accessoryViews.isEmpty ? nil : fitted(stack)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard Section(rawValue: indexPath.section) == .trades else { return }
        viewModel.toggleSelection(id: viewModel.items[indexPath.row].id)
        refresh()
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        Section(rawValue: indexPath.section) == .trades
    }
}
