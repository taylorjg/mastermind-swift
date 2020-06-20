//
//  extensions.swift
//  Mastermind
//
//  Created by Administrator on 20/06/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation

// https://www.hackingwithswift.com/example-code/language/how-to-count-matching-items-in-an-array
extension Collection {
    func count(where test: (Element) throws -> Bool) rethrows -> Int {
        return try self.filter(test).count
    }
}

// https://www.hackingwithswift.com/example-code/language/how-to-split-an-array-into-chunks
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
