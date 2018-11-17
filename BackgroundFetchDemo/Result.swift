//
//  Result.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

enum Result<V> {
    case success(V)
    case failure(Error)
}
