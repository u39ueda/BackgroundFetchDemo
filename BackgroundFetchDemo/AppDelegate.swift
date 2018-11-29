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
    let log = XCGLogger(identifier: "logger", includeDefaultDestinations: false)

    // Create a NSLog destination
    let sysLogDestination = AppleSystemLogDestination(owner: log, identifier: "logger.systemLog")
    sysLogDestination.outputLevel = .debug
    sysLogDestination.showLogIdentifier = false
    sysLogDestination.showFunctionName = true
    sysLogDestination.showThreadName = true
    sysLogDestination.showLevel = true
    sysLogDestination.showFileName = true
    sysLogDestination.showLineNumber = true
    sysLogDestination.showDate = true

    // Process this destination in the background
    sysLogDestination.logQueue = XCGLogger.logQueue

    // Add the destination to the logger
    log.add(destination: sysLogDestination)

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
    let networkManager = BackgroundNetworkManager(configuration: URLSessionConfiguration.background(withIdentifier: "net.u39-ueda.BackgroundFetchDemo.background"))
    var sampleDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        log.debug("\(launchOptions?.description ?? "(nil)")")
        log.debug("\(String(describing: UserDefaultsManager.shared.fetchData))")

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

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        log.info("identifier=\(identifier)")
        if identifier == networkManager.identifier {
            networkManager.handleEventsForBackgroundURLSession(completionHandler: completionHandler)
        } else {
            completionHandler()
        }
    }

    func checkFetchNeed(date: Date) -> Bool {
        if let fetchData = UserDefaultsManager.shared.fetchData {
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
        networkManager.download(url) { (result) in
            log.debug("\(result)")
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
                        let fetchResult = UIBackgroundFetchResult.newData
                        completionHandler(fetchResult)
                    }
                } else {
                    var fetchData = FetchData()
                    fetchData.lastFetchFailureDate = Date()
                    UserDefaultsManager.shared.fetchData = fetchData
                    log.debug("parse failure. fetchData=\(fetchData)")
                    let fetchResult = UIBackgroundFetchResult.failed
                    completionHandler(fetchResult)
                }
                try? FileManager.default.removeItem(at: tmpFileUrl)
            case let .failure(error):
                var fetchData = FetchData()
                fetchData.lastFetchFailureDate = Date()
                UserDefaultsManager.shared.fetchData = fetchData
                log.debug("download failure. error=\(error), fetchData=\(fetchData)")
                let fetchResult = UIBackgroundFetchResult.failed
                completionHandler(fetchResult)
            }
        }
    }

}

