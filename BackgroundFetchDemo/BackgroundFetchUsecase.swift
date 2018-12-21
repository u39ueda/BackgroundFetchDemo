//
//  BackgroundFetchUsecase.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/12/01.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

enum BackgroundFetchUsecaseResult {
    case success
    case skip
    case failed
}

struct BackgroundFetchUsecaseState: Codable {
}

class BackgroundFetchUsecase {
    var sampleDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }

    let networkManager: BackgroundNetworkManager
    var completionHandlerTable = [BackgroundDownloadTask: ((BackgroundFetchUsecaseResult) -> Void)]()

    init(networkManager: BackgroundNetworkManager = .background) {
        self.networkManager = networkManager
        networkManager.addObserver(self)
    }

    deinit {
        networkManager.removeObserver(self)
    }

    func fire(_ completionHandler: @escaping (BackgroundFetchUsecaseResult) -> Void) {
        if !checkFetchNeed(date: Date()) {
            completionHandler(.skip)
            return
        }
        requestData(completionHandler: completionHandler)
    }

    func checkFetchNeed(date: Date) -> Bool {
        if let fetchData = UserDefaultsManager.shared.fetchData {
            // Skip if 24h have not passed since the last fetch
            if let lastFetchDate = fetchData.lastFetchDate {
                let diff = date.timeIntervalSince(lastFetchDate)
                if 0 < diff && diff < 24 {
                    log.debug("lastFetchDate=\(lastFetchDate), diff=\(diff)")
                    return false
                }
            }
            // Skip if 5min have not passed since the last fetch failure
            if let lastFetchDate = fetchData.lastFetchFailureDate {
                let diff = date.timeIntervalSince(lastFetchDate)
                if 0 < diff && diff < 5 {
                    log.debug("lastFetchFailureDate=\(lastFetchDate), diff=\(diff)")
                    return false
                }
            }
        }
        return true
    }

    func requestData(completionHandler: @escaping (BackgroundFetchUsecaseResult) -> Void) {
        let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/sandbox-3dbc9.appspot.com/o/sample%2Fsample01.json?alt=media&token=482849a6-7105-4f88-9bbb-39c32201a846")!
        let task = networkManager.download(url) { (result) in
        }
        completionHandlerTable[task] = completionHandler
    }
}

extension BackgroundFetchUsecase: BackgroundNetworkManagerDelegate {
    func backgroundNetworkManager(_ manager: BackgroundNetworkManager, downloadTask: BackgroundDownloadTask, didFinish result: Result<(URL, URLResponse)>) {
        let decoder = sampleDecoder
        let completionHandler = completionHandlerTable[downloadTask] ?? { _ in }
        completionHandlerTable[downloadTask] = nil

        switch result {
        case let .success((tmpFileUrl, res)):
            if let data = FileManager.default.contents(atPath: tmpFileUrl.path),
                let sample = try? decoder.decode(Sample.self, from: data),
                let res = res as? HTTPURLResponse
            {
                DispatchQueue.main.async {
                    let lastModified = res.allHeaderFields["Last-Modified"] as? String ?? ""
                    log.debug("fetch success. \(sample), Last-Modified=\(lastModified)")
                    var fetchData = FetchData()
                    fetchData.sample = sample
                    fetchData.lastModified = lastModified
                    fetchData.lastFetchDate = Date()
                    UserDefaultsManager.shared.fetchData = fetchData
                    log.debug("fetchData=\(fetchData)")
                    completionHandler(.success)
                }
            } else {
                var fetchData = FetchData()
                fetchData.lastFetchFailureDate = Date()
                UserDefaultsManager.shared.fetchData = fetchData
                log.debug("parse failure. fetchData=\(fetchData)")
                completionHandler(.failed)
            }
            try? FileManager.default.removeItem(at: tmpFileUrl)
        case let .failure(error):
            var fetchData = FetchData()
            fetchData.lastFetchFailureDate = Date()
            UserDefaultsManager.shared.fetchData = fetchData
            log.debug("download failure. error=\(error), fetchData=\(fetchData)")
            completionHandler(.failed)
        }
    }
}
