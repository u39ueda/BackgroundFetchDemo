//
//  BackgroundNetworkManager.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

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

class BackgroundDownloadTask: Equatable, BackgroundTask {
    var task: URLSessionTask
    var completionHandler: ((Result<(URL, URLResponse)>) -> Void)?
    var fileError: Error?
    var response: URLResponse?
    var tempFileUrl: URL?
    init(task: URLSessionDownloadTask) {
        self.task = task
    }
    deinit {
        if let fileUrl = tempFileUrl {
            assert(!FileManager.default.fileExists(atPath: fileUrl.path), "temporary file should be cleanup. fileUrl=\(fileUrl)")
            cleanup()
        }
    }
    func cancel() {
        task.cancel()
    }
    func cleanup() {
        if let fileUrl = tempFileUrl, FileManager.default.fileExists(atPath: fileUrl.path) {
            try? FileManager.default.removeItem(at: fileUrl)
        }
    }
    public static func == (lhs: BackgroundDownloadTask, rhs: BackgroundDownloadTask) -> Bool {
        return lhs.task.taskIdentifier == rhs.task.taskIdentifier
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        log.debug("error=\(String(describing: error)).")
        if let error = error {
            cleanup()
            completionHandler?(.failure(error))
        } else if let fileError = self.fileError {
            cleanup()
            completionHandler?(.failure(fileError))
        } else if let fileUrl = tempFileUrl, let response = response {
            completionHandler?(.success((fileUrl, response)))
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
            self.tempFileUrl = tempFileUrl
        } catch let error {
            log.warning("move downloaded file failed. error=\(error)")
            self.fileError = error
        }
        self.response = downloadTask.response
    }
}

class BackgroundNetworkManager {
    private let session: URLSession
    private let trampoline = BackgroundNetworkManagerTrampoline()
    init(configuration: URLSessionConfiguration) {
        session = URLSession(configuration: configuration, delegate: trampoline, delegateQueue: nil)
    }

    var identifier: String {
        return session.configuration.identifier ?? ""
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
        let donwloadTask = BackgroundDownloadTask(task: task)
        donwloadTask.completionHandler = completion
        trampoline.taskTable[task.taskIdentifier] = donwloadTask

        task.resume()

        return donwloadTask
    }

    func handleEventsForBackgroundURLSession(completionHandler: @escaping () -> Void) {
        log.info()
        trampoline.handleEventsForBackgroundURLSessionCompletionHandler = completionHandler

        session.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) in
            log.debug("getTasks complete\ndata=\(dataTasks)\nupload=\(uploadTasks)\ndownload=\(downloadTasks)")
            downloadTasks.forEach { (task) in
                let downloadTask = BackgroundDownloadTask(task: task)
                self.trampoline.taskTable[task.taskIdentifier] = downloadTask
            }
        }
    }
}

private class BackgroundNetworkManagerTrampoline: NSObject, URLSessionDelegate {
    var taskTable = [Int: BackgroundTask]()
    var handleEventsForBackgroundURLSessionCompletionHandler: (() -> Void)?

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        log.info()
        handleEventsForBackgroundURLSessionCompletionHandler?()
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
