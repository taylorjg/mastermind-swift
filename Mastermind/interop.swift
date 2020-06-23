//
//  interop.swift
//  Mastermind
//
//  Created by Administrator on 22/06/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation

struct BestInterop {
    let count: UInt16
    let code: UInt16
}

func encodeCodeInterop(code: Code) -> UInt16 {
    let p0 = UInt16(code.p0.rawValue)
    let p1 = UInt16(code.p1.rawValue << 4)
    let p2 = UInt16(code.p2.rawValue << 8)
    let p3 = UInt16(code.p3.rawValue << 12)
    return p0 | p1 | p2 | p3
}

func decodeCodeInterop(encoded: UInt16) -> Code {
    let p0 = Peg(rawValue: Int(encoded & 0x000f))!
    let p1 = Peg(rawValue: Int((encoded & 0x00f0) >> 4))!
    let p2 = Peg(rawValue: Int((encoded & 0x0f00) >> 8))!
    let p3 = Peg(rawValue: Int((encoded & 0xf000) >> 12))!
    return Code(p0: p0, p1: p1, p2: p2, p3: p3)
}

func decodeBestInterop(bestInterop: BestInterop) -> (Int, Code) {
    let count = Int(bestInterop.count)
    let code = decodeCodeInterop(encoded: bestInterop.code)
    return (count, code)
}
