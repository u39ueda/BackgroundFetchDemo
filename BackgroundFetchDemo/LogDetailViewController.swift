//
//  LogDetailViewController.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/29.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import UIKit

class LogDetailViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!

    var fileURL: URL?

    override func viewDidLoad() {
        super.viewDidLoad()
        log.info()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        log.info()
        reloadFile()
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

    @IBAction func onReloadButton(_ sender: Any) {
        log.info()
        reloadFile()
    }

    private func reloadFile() {
        guard let fileURL = fileURL else { return }
        DispatchQueue.global().async {
            guard let data = FileManager.default.contents(atPath: fileURL.path) else { return }
            guard let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self.textView.text = text
            }
        }
    }
}
