//
//  LogListViewController.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/29.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class LogDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    private struct PathItem {
        var path: String
        var url: URL
    }

    private var pathItems = [PathItem]()

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pathItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.textLabel?.text = pathItems[indexPath.row].path
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return nil
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            removeFile(pathItems[indexPath.row])
            pathItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    private func removeFile(_ pathItem: PathItem) {
        do {
            try FileManager.default.removeItem(at: pathItem.url)
        } catch let e {
            log.warning("Remove file failed. error=\(e.localizedDescription)\n\(e)")
        }
    }

    func reloadFiles() {
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: docURL.path) else {
            log.warning("List files failed.")
            return
        }
        self.pathItems = files
            .filter { $0.hasSuffix(".txt") }
            .sorted()
            .map { PathItem(path: $0, url: docURL.appendingPathComponent($0)) }
    }

    func fileUrl(at indexPath: IndexPath) -> URL {
        return pathItems[indexPath.row].url
    }

}

class FetchDateDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    private class DateSection {
        var dateText: String
        var fetchDateList = [FetchDate]()
        init(_ dateText: String) {
            self.dateText = dateText
        }
    }
    private struct FetchDate {
        var date: Date
    }

    private var dateSections = [DateSection]()
    private let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return dateSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dateSections[section].fetchDateList.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        let date = dateSections[indexPath.section].fetchDateList[indexPath.row].date
        cell.textLabel?.text = formatter.string(from: date)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dateSections[section].dateText
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func reloadFiles() {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        var sectionTable = [String: DateSection]()
        UserDefaultsManager.shared.fetchDateList.forEach { (date) in
            let dateText = formatter.string(from: date)
            let section = sectionTable[dateText] ?? DateSection(dateText)
            sectionTable[dateText] = section
            section.fetchDateList.append(FetchDate(date: date))
        }
        self.dateSections = sectionTable.keys.sorted().compactMap {
            sectionTable[$0]
        }
    }

}

class LogListViewController: UITableViewController {

    enum SegmentType: Int {
        case log
        case fetchDate
    }

    typealias DataSourceType = UITableViewDataSource & UITableViewDelegate
    private var logData = LogDataSource()
    private var fetchDate = FetchDateDataSource()
    private var currentSecmentType: SegmentType = .log

    override func viewDidLoad() {
        super.viewDidLoad()

        let segmentedControl = UISegmentedControl(items: ["ログ", "取得日時"])
        segmentedControl.selectedSegmentIndex = currentSecmentType.rawValue
        segmentedControl.addTarget(self, action: #selector(onSegmentChanged(_:)), for: .valueChanged)
        navigationItem.titleView = segmentedControl
        log.info()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log.info()
        reloadFiles()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        log.info()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        log.info()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        log.info()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return dataSouce(currentSecmentType).numberOfSections?(in: tableView) ?? 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSouce(currentSecmentType).tableView(tableView, numberOfRowsInSection: section)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return dataSouce(currentSecmentType).tableView(tableView, cellForRowAt: indexPath)
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return dataSouce(currentSecmentType).tableView?(tableView, canEditRowAt: indexPath) ?? false
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        dataSouce(currentSecmentType).tableView?(tableView, commit: editingStyle, forRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return dataSouce(currentSecmentType).tableView?(tableView, titleForHeaderInSection: section) ?? nil
    }

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return dataSouce(currentSecmentType).tableView?(tableView, shouldHighlightRowAt: indexPath) ?? false
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch (segue.destination, sender) {
        case let (dest as LogDetailViewController, cell as UITableViewCell):
            guard let indexPath = tableView.indexPath(for: cell) else { return }
            dest.fileURL = logData.fileUrl(at: indexPath)
        default:
            fatalError("Unknown segue.")
        }
    }

    private func reloadFiles() {
        let start = Date()
        logData.reloadFiles()
        fetchDate.reloadFiles()
        let diff = Date().timeIntervalSince(start)
        log.debug("reload time=\(diff)")
        tableView.reloadData()
    }

    private func dataSouce(_ type: SegmentType) -> DataSourceType {
        switch type {
        case .log: return logData
        case .fetchDate: return fetchDate
        }
    }

    @objc
    public func onSegmentChanged(_ sender: UISegmentedControl) {
        guard let type = SegmentType(rawValue: sender.selectedSegmentIndex) else {
            return
        }
        currentSecmentType = type
        reloadFiles()
    }
}
