//
//  Sample.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

struct Sample: Codable {
    var data = [SampleData]()
}

struct SampleData: Codable {
    var date: Date?
    var title: String?
}
