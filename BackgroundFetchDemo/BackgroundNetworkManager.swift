//
//  BackgroundNetworkManager.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

class BackgroundNetworkTask: Equatable {
    let task: URLSessionTask
    init(task: URLSessionTask) {
        self.task = task
    }
    func cancel() {
        task.cancel()
    }
    public static func == (lhs: BackgroundNetworkTask, rhs: BackgroundNetworkTask) -> Bool {
        return lhs.task.taskIdentifier == rhs.task.taskIdentifier
    }
}

class BackgroundNetworkManager {
    private let session: URLSession
    private let trampoline = BackgroundNetworkManagerTrampoline()
    init(configuration: URLSessionConfiguration) {
        session = URLSession(configuration: configuration, delegate: trampoline, delegateQueue: OperationQueue.main)
    }

    @discardableResult
    func get(_ url: URL, completion: @escaping (Result<(Data, URLResponse)>) -> Void) -> BackgroundNetworkTask {
        let task = session.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
            } else if let data = data, let response = response {
                completion(.success((data, response)))
            } else {
                fatalError("both error and response are nil.")
            }
        }
        task.resume()
        return BackgroundNetworkTask(task: task)
    }
}

private class BackgroundNetworkManagerTrampoline: NSObject, URLSessionDelegate {
}
