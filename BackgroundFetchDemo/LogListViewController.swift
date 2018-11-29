//
//  LogListViewController.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/29.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import UIKit

private let reuseIdentifier = "Cell"

class LogListViewController: UITableViewController {

    private struct PathItem {
        var path: String
        var url: URL
    }

    private var pathItems = [PathItem]()

    override func viewDidLoad() {
        super.viewDidLoad()
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

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pathItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)
        cell.textLabel?.text = pathItems[indexPath.row].path
        return cell
    }

    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            removeFile(pathItems[indexPath.row])
            pathItems.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch (segue.destination, sender) {
        case let (dest as LogDetailViewController, cell as UITableViewCell):
            guard let indexPath = tableView.indexPath(for: cell) else { return }
            dest.fileURL = pathItems[indexPath.row].url
        default:
            fatalError("Unknown segue.")
        }
    }

    private func reloadFiles() {
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: docURL.path) else {
            log.warning("List files failed.")
            return
        }
        self.pathItems = files
            .filter { $0.hasSuffix(".txt") }
            .sorted()
            .map { PathItem(path: $0, url: docURL.appendingPathComponent($0)) }
        tableView.reloadData()
    }

    private func removeFile(_ pathItem: PathItem) {
        do {
            try FileManager.default.removeItem(at: pathItem.url)
        } catch let e {
            log.warning("Remove file failed. error=\(e.localizedDescription)\n\(e)")
        }
    }
}
