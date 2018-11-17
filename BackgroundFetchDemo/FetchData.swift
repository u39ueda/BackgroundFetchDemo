//
//  FetchData.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

struct FetchData: Codable {
    var lastModified: String = ""
    var sample: Sample?
    var lastFetchDate: Date?
    var lastFetchFailureDate: Date?
}
