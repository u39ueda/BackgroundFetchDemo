//
//  AppDelegate.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import UIKit

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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        application.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        print("\(#function), \(launchOptions?.description ?? "(nil)")")
        if let rawFetchData = UserDefaults.standard.object(forKey: "fetchData") as? Data {
            let fetchData = try? fetchDataDecoder.decode(FetchData.self, from: rawFetchData)
            print("\(#function), \(fetchData)")
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
        print("\(Date()), \(#function)")
        if let rawFetchData = UserDefaults.standard.object(forKey: "fetchData") as? Data {
            let fetchData = try? fetchDataDecoder.decode(FetchData.self, from: rawFetchData)
            if let lastFetchDate = fetchData?.lastFetchDate {
                let diff = Date().timeIntervalSince(lastFetchDate)
                if 0 < diff && diff < 24 * 60 * 60 {
                    print("\(Date()), \(#function), lastFetchDate=\(lastFetchDate), diff=\(diff)")
                    completionHandler(.noData)
                    return
                }
            }
            if let lastFetchDate = fetchData?.lastFetchFailureDate {
                let diff = Date().timeIntervalSince(lastFetchDate)
                if 0 < diff && diff < 5 * 60 {
                    print("\(Date()), \(#function), lastFetchFailureDate=\(lastFetchDate), diff=\(diff)")
                    completionHandler(.noData)
                    return
                }
            }
        }
        requestData(completionHandler: completionHandler)
    }

    func requestData(completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/sandbox-3dbc9.appspot.com/o/sample%2Fsample01.json?alt=media&token=482849a6-7105-4f88-9bbb-39c32201a846")!
        let decoder = sampleDecoder
        let encoder = fetchDataEncoder
        networkManager.get(url) { (result) in
            print("\(Date()), \(#function), \(result)")
            let fetchResult: UIBackgroundFetchResult
            switch result {
            case let .success((data, res)):
                if let sample = try? decoder.decode(Sample.self, from: data), let res = res as? HTTPURLResponse {
                    let lastModified = res.allHeaderFields["Last-Modified"] as? String ?? ""
                    print("\(#function), fetch success. \(sample), Last-Modified=\(lastModified)")
                    var fetchData = FetchData()
                    fetchData.sample = sample
                    fetchData.lastModified = lastModified
                    fetchData.lastFetchDate = Date()
                    let value = try? encoder.encode(fetchData)
                    UserDefaults.standard.set(value, forKey: "fetchData")
                    print("\(#function). fetchData=\(fetchData)")
                    fetchResult = .newData
                } else {
                    var fetchData = FetchData()
                    fetchData.lastFetchFailureDate = Date()
                    let value = try? encoder.encode(fetchData)
                    UserDefaults.standard.set(value, forKey: "fetchData")
                    print("\(#function), parse failure. fetchData=\(fetchData)")
                    fetchResult = .noData
                }
            case let .failure(error):
                var fetchData = FetchData()
                fetchData.lastFetchFailureDate = Date()
                let value = try? encoder.encode(fetchData)
                UserDefaults.standard.set(value, forKey: "fetchData")
                print("\(#function), download failure. error=\(error), fetchData=\(fetchData)")
                fetchResult = .noData
            }
            completionHandler(fetchResult)
        }
    }

}

