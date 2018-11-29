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
        }
    }
}
