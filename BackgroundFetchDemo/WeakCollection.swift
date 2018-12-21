//
//  WeakCollection.swift
//  BackgroundFetchDemo
//
//  Created by 植田裕作 on 2018/12/01.
//  Copyright © 2018 Yusaku Ueda. All rights reserved.
//

import Foundation

protocol WeakReference {
    associatedtype Element
    var value: Element? { get }
}

protocol WeakCollection: Sequence {
    associatedtype WeakElement: WeakReference where WeakElement.Element == Element

    associatedtype WeakCollection: Collection where WeakCollection.Element == WeakElement

    var weakCollection: WeakCollection { get set }
}

extension WeakCollection {
    var collection: [Element] { return weakCollection.compactMap { $0.value } }
    func makeIterator() -> IndexingIterator<Array<Element>> { return collection.makeIterator() }
    func dropFirst(_ k: Int) -> ArraySlice<Element> { return collection.dropFirst(k) }
    func dropLast(_ k: Int) -> ArraySlice<Element> { return collection.dropLast(k) }
    func drop(while predicate: (Element) throws -> Bool) rethrows -> ArraySlice<Element> { return try collection.drop(while: predicate) }
    func prefix(_ maxLength: Int) -> ArraySlice<Element> { return collection.prefix(maxLength) }
    func prefix(while predicate: (Element) throws -> Bool) rethrows -> ArraySlice<Element> { return try collection.prefix(while: predicate) }
    func suffix(_ maxLength: Int) -> ArraySlice<Element> { return collection.suffix(maxLength) }
    func split(maxSplits: Int, omittingEmptySubsequences: Bool, whereSeparator isSeparator: (Element) throws -> Bool) rethrows -> [ArraySlice<Element>] { return try collection.split(maxSplits: maxSplits, omittingEmptySubsequences: omittingEmptySubsequences, whereSeparator: isSeparator) }
}
