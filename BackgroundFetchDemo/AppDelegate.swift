//
//  AppDelegate.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import UIKit
import XCGLogger

let log: XCGLogger = {
    // Create a logger object with no destinations
    let log = XCGLogger(identifier: "logger", includeDefaultDestinations: true)

    // Create a file log destination
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyyMMdd'-'HHmmss"
    let docsDirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let logFileURL = docsDirURL.appendingPathComponent(formatter.string(from: Date()) + ".txt")
    let fileDestination = FileDestination(writeToFile: logFileURL.path, identifier: "logger.fileDestination")

    // Optionally set some configuration options
    fileDestination.outputLevel = .debug
    fileDestination.showLogIdentifier = false
    fileDestination.showFunctionName = true
    fileDestination.showThreadName = true
    fileDestination.showLevel = true
    fileDestination.showFileName = true
    fileDestination.showLineNumber = true
    fileDestination.showDate = true

    // Process this destination in the background
    fileDestination.logQueue = XCGLogger.logQueue

    // Add the destination to the logger
    log.add(destination: fileDestination)

    // Add basic app info, version info etc, to the start of the logs
    log.logAppDetails()
    return log
}()

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let networkManager = BackgroundNetworkManager(configuration: URLSessionConfiguration.default)
    var sampleDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }
    var fetchDataEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
    var fetchDataDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    var fetchData: FetchData? {
        get {
            if let rawFetchData = UserDefaults.standard.object(forKey: "fetchData") as? Data {
                return try? fetchDataDecoder.decode(FetchData.self, from: rawFetchData)
            }
            return nil
        }
        set {
            let value = try? fetchDataEncoder.encode(newValue)
            UserDefaults.standard.set(value, forKey: "fetchData")
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        log.debug("\(launchOptions?.description ?? "(nil)")")
        if let rawFetchData = UserDefaults.standard.object(forKey: "fetchData") as? Data {
            let fetchData = try? fetchDataDecoder.decode(FetchData.self, from: rawFetchData)
            log.debug("\(fetchData)")
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        log.debug("")
        if !checkFetchNeed(date: Date()) {
            completionHandler(.noData)
            return
        }
        requestData(completionHandler: completionHandler)
    }

    func checkFetchNeed(date: Date) -> Bool {
        if let fetchData = self.fetchData {
            // Skip if 24h have not passed since the last fetch
            if let lastFetchDate = fetchData.lastFetchDate {
                let diff = date.timeIntervalSince(lastFetchDate)
                if 0 < diff && diff < 24 * 60 * 60 {
                    log.debug("lastFetchDate=\(lastFetchDate), diff=\(diff)")
                    return false
                }
            }
            // Skip if 5min have not passed since the last fetch failure
            if let lastFetchDate = fetchData.lastFetchFailureDate {
                let diff = date.timeIntervalSince(lastFetchDate)
                if 0 < diff && diff < 5 * 60 {
                    log.debug("lastFetchFailureDate=\(lastFetchDate), diff=\(diff)")
                    return false
                }
            }
        }
        return true
    }

    func requestData(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/sandbox-3dbc9.appspot.com/o/sample%2Fsample01.json?alt=media&token=482849a6-7105-4f88-9bbb-39c32201a846")!
        let decoder = sampleDecoder
        networkManager.get(url) { (result) in
            log.debug("\(result)")
            let fetchResult: UIBackgroundFetchResult
            switch result {
            case let .success((data, res)):
                if let sample = try? decoder.decode(Sample.self, from: data), let res = res as? HTTPURLResponse {
                    let lastModified = res.allHeaderFields["Last-Modified"] as? String ?? ""
                    log.debug("fetch success. \(sample), Last-Modified=\(lastModified)")
                    var fetchData = FetchData()
                    fetchData.sample = sample
                    fetchData.lastModified = lastModified
                    fetchData.lastFetchDate = Date()
                    self.fetchData = fetchData
                    log.debug("fetchData=\(fetchData)")
                    fetchResult = .newData
                } else {
                    var fetchData = FetchData()
                    fetchData.lastFetchFailureDate = Date()
                    self.fetchData = fetchData
                    log.debug("parse failure. fetchData=\(fetchData)")
                    fetchResult = .failed
                }
            case let .failure(error):
                var fetchData = FetchData()
                fetchData.lastFetchFailureDate = Date()
                self.fetchData = fetchData
                log.debug("download failure. error=\(error), fetchData=\(fetchData)")
                fetchResult = .failed
            }
            completionHandler(fetchResult)
        }
    }

}

