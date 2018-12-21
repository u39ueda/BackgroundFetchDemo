//
//  BackgroundFetchDemoTests.swift
//  BackgroundFetchDemoTests
//
//  Created by 植田裕作 on 2018/11/17.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import XCTest
@testable import BackgroundFetchDemo

protocol HogeP: class {}
class Hoge: HogeP {}

struct WeakHoge: WeakReference {
    typealias Element = HogeP

    weak var value: Element?
    init(_ value: Element) {
        self.value = value
    }
}

struct HogePCollection: WeakCollection {
    typealias WeakElement = WeakHoge
    typealias Element = HogeP
    var weakCollection = [WeakElement]()
    mutating func append(_ element: Element) {
        remove(element)
        weakCollection.append(WeakElement(element))
    }
    mutating func remove(_ element: Element) {
        weakCollection.removeAll(where: { $0.value == nil || $0.value === element })
    }
}

class BackgroundFetchDemoTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    func test_backgroundNetworkManager_success() {
        let exp = expectation(description: #function)
        let manager = BackgroundNetworkManager(configuration: URLSessionConfiguration.default)
        let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/sandbox-3dbc9.appspot.com/o/sample%2Fsample01.json?alt=media&token=482849a6-7105-4f88-9bbb-39c32201a846")!
        manager.get(url) { (result) in
            print("\(#function), \(result)")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func test_backgroundNetworkManager_cancel() {
        let exp = expectation(description: #function)
        let manager = BackgroundNetworkManager(configuration: URLSessionConfiguration.default)
        let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/sandbox-3dbc9.appspot.com/o/sample%2Fsample01.json?alt=media&token=482849a6-7105-4f88-9bbb-39c32201a846")!
        let task = manager.get(url) { (result) in
            print("\(#function), \(result)")
            switch result {
            case let .failure(error as NSError):
                XCTAssertEqual(error.domain, NSURLErrorDomain)
                XCTAssertEqual(error.code, NSURLErrorCancelled)
            case .success:
                XCTFail("not cancelled.")
            }
            exp.fulfill()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            task.cancel()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func test_backgroundNetworkManager_download_success() {
        let exp = expectation(description: #function)
        let manager = BackgroundNetworkManager(configuration: URLSessionConfiguration.background(withIdentifier: "\(#function)"))
        let url = URL(string: "https://firebasestorage.googleapis.com/v0/b/sandbox-3dbc9.appspot.com/o/sample%2Fsample01.json?alt=media&token=482849a6-7105-4f88-9bbb-39c32201a846")!
        manager.download(url) { (result) in
            print("\(#function), \(result)")
            exp.fulfill()
        }
        wait(for: [exp], timeout: 10.0)
    }

    func test_parseSample() {
        let fileUrl = Bundle(for: type(of: self)).url(forResource: "sample01", withExtension: "json")!
        let data = try! Data(contentsOf: fileUrl)
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 9 * 60 * 60)
        decoder.dateDecodingStrategy = .formatted(formatter)
        let sample = try? decoder.decode(Sample.self, from: data)
        XCTAssertNotNil(sample, "decode failure.")
    }

    func test_encodeFetchData() {
        var data = FetchData()
        data.lastModified = "Sat, 17 Nov 2018 02:43:26 GMT"
        data.sample = Sample(data: [SampleData(date: Date(), title: "title")])
        data.lastFetchDate = Date()
        data.lastFetchFailureDate = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let rawData = try? encoder.encode(data)
        XCTAssertNotNil(rawData, "decode failure.")
        print("\(rawData.flatMap { String(data: $0, encoding: .utf8) } ?? "nil")")
    }

    func test_WeakCollection() {
        let p1: HogeP = Hoge()
        let p2: HogeP = Hoge()
        // relase weak object
        do {
            var array = HogePCollection()
            autoreleasepool {
                let p: HogeP = Hoge()
                array.append(p)
                XCTAssertEqual(array.collection.count, 1)
            }
            XCTAssertEqual(array.collection.count, 0)
        }

        // remove object
        do {
            var array = HogePCollection()
            array.append(p1)
            array.append(p2)
            XCTAssertEqual(array.collection.count, 2)

            array.remove(p2)
            XCTAssertEqual(array.collection.count, 1)
        }

        // forEach object
        do {
            var array = HogePCollection()
            array.append(p1)
            array.append(p2)
            var i = 0
            array.forEach({ (hoge) in
                switch i {
                case 0: XCTAssertTrue(hoge === p1)
                case 1: XCTAssertTrue(hoge === p2)
                default: XCTFail()
                }
                i += 1
            })
        }
    }

}
