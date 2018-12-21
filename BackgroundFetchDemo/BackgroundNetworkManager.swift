//
//  BackgroundNetworkManager.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

struct BackgroundDownloadTaskError: Error, Codable {
    var domain: String
    var code: Int
    enum CodingKeys: String, CodingKey {
        case domain
        case code
    }
    init(_ error: Error) {
        let e = error as NSError
        self.init(domain: e.domain, code: e.code)
    }
    init(domain: String, code: Int) {
        self.domain = domain
        self.code = code
    }
}

protocol BackgroundTask {
    var task: URLSessionTask { get }
    func cancel()
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?)
}

class BackgroundDataTask: Equatable, BackgroundTask {
    let task: URLSessionTask
    var completionHandler: ((Result<(Data, URLResponse)>) -> Void)?
    var error: Error?
    var response: URLResponse?
    var data: Data?
    init(task: URLSessionDataTask) {
        self.task = task
    }
    func cancel() {
        task.cancel()
    }
    public static func == (lhs: BackgroundDataTask, rhs: BackgroundDataTask) -> Bool {
        return lhs.task.taskIdentifier == rhs.task.taskIdentifier
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        log.debug("error=\(String(describing: error)).")
        self.error = error
        if let error = error {
            completionHandler?(.failure(error))
        } else if let data = data, let response = response {
            completionHandler?(.success((data, response)))
        } else {
            fatalError("both error and response are nil.")
        }
    }
}

extension BackgroundDataTask {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        log.debug("response=\(response).")
        self.response = response
        if let contentLength = contentLength(response) {
            self.data = Data(capacity: contentLength)
        } else {
            self.data = Data()
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        precondition(self.data != nil)
        log.debug("data=\(data).")
        self.data?.append(data)
    }
    private func contentLength(_ response: URLResponse) -> Int? {
        guard let res = response as? HTTPURLResponse else {
            return nil
        }
        guard let contentLength = res.allHeaderFields["Content-Length"] as? String else {
            return nil
        }
        return Int(contentLength)
    }
}

class BackgroundDownloadTask: Equatable, Hashable, BackgroundTask {
    var sessionIdentifier: String
    var _task: URLSessionTask!
    var task: URLSessionTask { return _task }
    var contentData: ContentData
    var completionHandler: ((BackgroundDownloadTask, Result<(URL, URLResponse)>) -> Void)?
    struct ContentData: Codable {
        var fileError: BackgroundDownloadTaskError?
        var tempFileUrl: URL?

        enum CodingKeys: String, CodingKey {
            case fileError
            case tempFileUrl
        }
    }
    var identifier: String {
        return "\(sessionIdentifier)_\(task.taskIdentifier)"
    }
    init(sessionId: String, task: URLSessionDownloadTask, contentData: ContentData = ContentData()) {
        self.sessionIdentifier = sessionId
        self._task = task
        self.contentData = contentData
    }
    deinit {
        if let fileUrl = contentData.tempFileUrl {
            assert(!FileManager.default.fileExists(atPath: fileUrl.path), "temporary file should be cleanup. fileUrl=\(fileUrl)")
            cleanup()
        }
    }
    func cancel() {
        task.cancel()
    }
    func cleanup() {
        if let fileUrl = contentData.tempFileUrl, FileManager.default.fileExists(atPath: fileUrl.path) {
            try? FileManager.default.removeItem(at: fileUrl)
        }
    }
    public static func == (lhs: BackgroundDownloadTask, rhs: BackgroundDownloadTask) -> Bool {
        return lhs.identifier == rhs.identifier
    }
    public var hashValue: Int {
        return identifier.hashValue
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        log.debug("error=\(String(describing: error)).")
        if let error = error {
            cleanup()
            completionHandler?(self, .failure(error))
        } else if let fileError = contentData.fileError {
            cleanup()
            completionHandler?(self, .failure(fileError))
        } else if let fileUrl = contentData.tempFileUrl, let response = task.response {
            completionHandler?(self, .success((fileUrl, response)))
        } else {
            fatalError("both error and response are nil.")
        }
    }
}

extension BackgroundDownloadTask {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        log.debug("location=\(location), response\(String(describing: downloadTask.response)).")
        let fm = FileManager.default
        let downloadDirUrl = fm.temporaryDirectory.appendingPathComponent("download")
        if !fm.fileExists(atPath: downloadDirUrl.path) {
            try? fm.createDirectory(at: downloadDirUrl, withIntermediateDirectories: true, attributes: nil)
        }
        let tempFileUrl = downloadDirUrl.appendingPathComponent(UUID().uuidString)
        log.debug("move downloaded file to temporary file.\nfrom=\(location)\nto=\(tempFileUrl)")
        do {
            try fm.moveItem(at: location, to: tempFileUrl)
            contentData.tempFileUrl = tempFileUrl
        } catch let error {
            log.warning("move downloaded file failed. error=\(error)")
            contentData.fileError = BackgroundDownloadTaskError(error)
        }
    }
}

protocol BackgroundNetworkManagerDelegate: class {
    func backgroundNetworkManager(_ manager: BackgroundNetworkManager, downloadTask: BackgroundDownloadTask, didFinish result: Result<(URL, URLResponse)>)
}

struct WeakBackgroundNetworkManagerDelegate: WeakReference {
    typealias Element = BackgroundNetworkManagerDelegate

    weak var value: Element?
    init(_ value: Element) {
        self.value = value
    }
}

struct BackgroundNetworkManagerDelegateCollection: WeakCollection {
    typealias WeakElement = WeakBackgroundNetworkManagerDelegate
    typealias Element = BackgroundNetworkManagerDelegate
    var weakCollection = [WeakElement]()
    mutating func append(_ element: Element) {
        remove(element)
        weakCollection.append(WeakElement(element))
    }
    mutating func remove(_ element: Element) {
        weakCollection.removeAll(where: { $0.value == nil || $0.value === element })
    }
}

class BackgroundNetworkManager {
    private let session: URLSession
    private let trampoline: BackgroundNetworkManagerTrampoline
    private let userDefaults: UserDefaultsManager
    private var observers = BackgroundNetworkManagerDelegateCollection()

    var identifier: String {
        return trampoline.identifier
    }

    static let background = BackgroundNetworkManager(configuration: backgroundConfig)
    static var backgroundConfig: URLSessionConfiguration {
        let config = URLSessionConfiguration.background(withIdentifier: "net.u39-ueda.BackgroundFetchDemo.background")
        return config
    }

    init(configuration: URLSessionConfiguration,
         userDefaults: UserDefaultsManager = UserDefaultsManager.shared)
    {
        trampoline = BackgroundNetworkManagerTrampoline(identifier: configuration.identifier ?? "")
        session = URLSession(configuration: configuration, delegate: trampoline, delegateQueue: nil)
        self.userDefaults = userDefaults

        session.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) in
            log.debug("getTasks complete\ndata=\(dataTasks)\nupload=\(uploadTasks)\ndownload=\(downloadTasks)")
            let identifier = self.identifier
            let downloadContentData = self.userDefaults.downloadContentData
            var newDownloadContentData = [String: BackgroundDownloadTask.ContentData]()
            downloadTasks.forEach { (task) in
                let key = UserDefaultsManager.downloadContentKey(sessionIdentifier: identifier, task: task)
                if let contentData = downloadContentData[key] {
                    let downloadTask = BackgroundDownloadTask(sessionId: identifier, task: task, contentData: contentData)
                    self.trampoline.taskTable[task.taskIdentifier] = downloadTask
                    newDownloadContentData[key] = contentData
                }
            }
            log.debug("remove content data=\(downloadContentData.filter { newDownloadContentData[$0.key] == nil })")
            self.userDefaults.downloadContentData = newDownloadContentData
        }
    }

    @discardableResult
    func get(_ url: URL, completion: @escaping (Result<(Data, URLResponse)>) -> Void) -> BackgroundDataTask {
        let task = session.dataTask(with: url)
        let dataTask = BackgroundDataTask(task: task)
        dataTask.completionHandler = completion
        trampoline.taskTable[task.taskIdentifier] = dataTask

        task.resume()

        return dataTask
    }

    @discardableResult
    func download(_ url: URL, completion: @escaping (Result<(URL, URLResponse)>) -> Void) -> BackgroundDownloadTask {
        let task = session.downloadTask(with: url)
        let downloadTask = BackgroundDownloadTask(sessionId: identifier, task: task)
        downloadTask.completionHandler = { [weak self] (downloadTask, result) in
            guard let self = self else { return }
            completion(result)
            self.observers.forEach { (observer) in
                observer.backgroundNetworkManager(self, downloadTask: downloadTask, didFinish: result)
            }
        }
        trampoline.taskTable[task.taskIdentifier] = downloadTask
        userDefaults.addDownloadTask(task: downloadTask)

        task.resume()

        return downloadTask
    }

    func handleEventsForBackgroundURLSession(completionHandler: @escaping () -> Void) {
        log.info()
        trampoline.handleEventsForBackgroundURLSessionCompletionHandler = completionHandler
    }

    func addObserver(_ observer: BackgroundNetworkManagerDelegate) {
        observers.append(observer)
    }

    func removeObserver(_ observer: BackgroundNetworkManagerDelegate) {
        observers.remove(observer)
    }
}

private class BackgroundNetworkManagerTrampoline: NSObject, URLSessionDelegate {
    let identifier: String
    var taskTable = [Int: BackgroundTask]()
    var handleEventsForBackgroundURLSessionCompletionHandler: (() -> Void)?

    required init(identifier: String) {
        self.identifier = identifier
        super.init()
    }

    override convenience init() {
        self.init(identifier: "")
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        log.info()
        guard let completionHandler = self.handleEventsForBackgroundURLSessionCompletionHandler else {
            return
        }
        self.handleEventsForBackgroundURLSessionCompletionHandler = nil

        DispatchQueue.main.async {
            completionHandler()
        }
    }
}

extension BackgroundNetworkManagerTrampoline: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let networkTask = taskTable[task.taskIdentifier] else {
            log.debug("task not found.")
            return
        }
        networkTask.urlSession(session, task: task, didCompleteWithError: error)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let networkTask = taskTable[dataTask.taskIdentifier] as? BackgroundDataTask else {
            log.debug("task not found.")
            return
        }
        networkTask.urlSession(session, dataTask: dataTask, didReceive: response, completionHandler: completionHandler)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let networkTask = taskTable[dataTask.taskIdentifier] as? BackgroundDataTask else {
            log.debug("task not found.")
            return
        }
        networkTask.urlSession(session, dataTask: dataTask, didReceive: data)
    }
}

extension BackgroundNetworkManagerTrampoline: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let networkTask = taskTable[downloadTask.taskIdentifier] as? BackgroundDownloadTask else {
            log.debug("task not found.")
            return
        }
        networkTask.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
    }
}
