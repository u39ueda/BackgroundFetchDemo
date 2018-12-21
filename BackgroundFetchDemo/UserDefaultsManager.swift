//
//  UserDefaultsManager.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/29.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

class UserDefaultsManager {
    static let shared = UserDefaultsManager()

    var dataEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    var dataDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    var fetchData: FetchData? {
        get {
            guard let rawData = UserDefaults.standard.data(forKey: "fetchData") else {
                return nil
            }
            return try? dataDecoder.decode(FetchData.self, from: rawData)
        }
        set {
            let value = try? dataEncoder.encode(newValue)
            UserDefaults.standard.set(value, forKey: "fetchData")
            UserDefaults.standard.synchronize()
        }
    }

    var downloadContentData: [String: BackgroundDownloadTask.ContentData] {
        get {
            guard let rawData = UserDefaults.standard.data(forKey: "downloadTasks") else {
                return [:]
            }
            guard let contentData = try? dataDecoder.decode([String: BackgroundDownloadTask.ContentData].self, from: rawData) else {
                return [:]
            }
            return contentData
        }
        set {
            let value = try? dataEncoder.encode(newValue)
            UserDefaults.standard.set(value, forKey: "downloadTasks")
            UserDefaults.standard.synchronize()
        }
    }
    static func downloadContentKey(sessionIdentifier: String, task: URLSessionTask) -> String {
        return "\(sessionIdentifier)_\(task.taskIdentifier)"
    }
}

extension UserDefaultsManager {
    func addDownloadTask(task: BackgroundDownloadTask) {
        var tasks = self.downloadContentData
        let key = UserDefaultsManager.downloadContentKey(sessionIdentifier: task.sessionIdentifier, task: task.task)
        tasks[key] = task.contentData
        self.downloadContentData = tasks
    }
}
