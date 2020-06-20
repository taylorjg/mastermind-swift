//
//  main.swift
//  Mastermind
//
//  Created by Administrator on 19/06/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation

extension Collection {
    func count(where test: (Element) throws -> Bool) rethrows -> Int {
        return try self.filter(test).count
    }
}

enum Peg: CustomStringConvertible, CaseIterable {
    case red
    case green
    case blue
    case yellow
    case black
    case white
    
    var description: String {
        switch self {
        case Peg.red: return "R"
        case Peg.green: return "G"
        case Peg.blue: return "B"
        case Peg.yellow: return "Y"
        case Peg.black: return "b"
        case Peg.white: return "w"
        }
    }
}

struct Code: CustomStringConvertible {
    let p0: Peg
    let p1: Peg
    let p2: Peg
    let p3: Peg
    
    var pegs: [Peg] {
        get {
            return [p0, p1, p2, p3]
        }
    }
    
    var description: String {
        return "\(p0)-\(p1)-\(p2)-\(p3)"
    }
}

struct Score: CustomStringConvertible, Equatable {
    let blacks: Int
    let whites: Int
    
    var indicatesWin: Bool {
        return blacks == 4
    }
    
    var description: String {
        let bs = String(repeating: "B", count: blacks)
        let ws = String(repeating: "W", count: whites)
        return bs + ws
    }
}

let allPegs: [Peg] = Peg.allCases

var allCodes: [Code] {
    var codes = [Code]()
    for p0 in allPegs {
        for p1 in allPegs {
            for p2 in allPegs {
                for p3 in allPegs {
                    codes.append(Code(p0: p0, p1: p1, p2: p2, p3: p3))
                }
            }
        }
    }
    return codes
}

var allScores: [Score] {
    var scores = [Score]()
    for blacks in 0...4 {
        for whites in 0...4 {
            if blacks + whites <= 4 && !(blacks == 3 && whites == 1){
                scores.append(Score(blacks: blacks, whites: whites))
            }
        }
    }
    return scores
}

func evaluateScore(code1: Code, code2: Code) -> Score {
    let mins = allPegs.map { peg -> Int in
        let numMatchingCode1Pegs = code1.pegs.count { $0 == peg }
        let numMatchingCode2Pegs = code2.pegs.count { $0 == peg }
        return min(numMatchingCode1Pegs, numMatchingCode2Pegs)
    }
    let sumOfMins = mins.reduce(0, +)
    let blacks = Array(zip(code1.pegs, code2.pegs)).count { $0.0 == $0.1 }
    let whites = sumOfMins - blacks
    return Score(blacks: blacks, whites: whites)
}

func getRandomSecret() -> Code {
    allCodes.randomElement()!
}

let initialGuess = Code(p0: .red, p1: .red, p2: .green, p3: .green)

func chooseNextGuess(untried: [Code]) -> Code {
    let best = allCodes.reduce((Int.max, initialGuess), { (currentBest, code) in
        let count = allScores.reduce(0, { (currentMax, score) in
            let count = untried.count { evaluateScore(code1: code, code2: $0) == score }
            return max(currentMax, count)
        })
        return count < currentBest.0 ? (count, code) : currentBest
    })
    return best.1
}

func recursiveSolveStep(attempt: (Code) -> Score, untried: [Code]) -> Code {
    let guess = untried.count == allCodes.count
        ? initialGuess
        : (untried.count == 1 ? untried[0] : chooseNextGuess(untried: untried))
    let score = attempt(guess)
    if score.indicatesWin {
        return guess
    }
    let filteredUntried = untried.filter { code in
        evaluateScore(code1: code, code2: guess) == score
    }
    return recursiveSolveStep(attempt: attempt, untried: filteredUntried)
}

func solve(attempt: (Code) -> Score) -> Code {
    recursiveSolveStep(attempt: attempt, untried: allCodes)
}

let secret = getRandomSecret()
let answer = solve { guess in
    let score = evaluateScore(code1: secret, code2: guess)
    let date = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.timeStyle = .medium
    let dateString = dateFormatter.string(from: date)
    print("[\(dateString)] guess: \(guess); score: \(score)")
    return score
}
print("answer: \(answer)")
