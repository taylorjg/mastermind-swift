//
//  main.swift
//  Mastermind
//
//  Created by Administrator on 19/06/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation

enum Mode {
    case singleThread
    case multipleThreads
    case metalComputeShader
}

var mode: Mode = .singleThread

enum Peg: CaseIterable, CustomStringConvertible {
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

struct Score: Equatable, CustomStringConvertible {
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

func randomSecret() -> Code {
    allCodes.randomElement()!
}

let initialGuess = Code(p0: .red, p1: .red, p2: .green, p3: .green)

func task(untried: [Code], chunk: [Code]) -> (Int, Code) {
    let best = chunk.reduce((Int.max, initialGuess), { (currentBest, code) in
        let count = allScores.reduce(0, { (currentMax, score) in
            let count = untried.count { evaluateScore(code1: code, code2: $0) == score }
            return max(currentMax, count)
        })
        return count < currentBest.0 ? (count, code) : currentBest
    })
    return best
}

func chooseNextGuessSingleThread(untried: [Code]) -> Code {
    let best = task(untried: untried, chunk: allCodes)
    return best.1
}

func chooseNextGuessMultipleThreads(untried: [Code]) -> Code {
    let numThreads = 8
    let chunkSize = allCodes.count / numThreads
    let chunks = allCodes.chunked(into: chunkSize)
    var bests = [(Int, Code)]()
    let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
    let dispatchGroup = DispatchGroup()
    let dispatchSemaphore = DispatchSemaphore(value: 1)
    for threadNum in 0..<numThreads {
        let chunk = chunks[threadNum]
        dispatchQueue.async(group: dispatchGroup) {
            let best = task(untried: untried, chunk: chunk)
            dispatchSemaphore.wait()
            defer { dispatchSemaphore.signal() }
            bests.append(best)
        }
    }
    dispatchGroup.wait()
    log(message: "bests: \(bests)")
    let best = bests.min(by: { $0.0 < $1.0 })!
    log(message: "best: \(best)")
    return best.1
}

func chooseNextGuessMetalComputeShader(untried: [Code]) -> Code {
    return initialGuess
}

func chooseNextGuess(untried: [Code]) -> Code {
    log(message: "untried.count: \(untried.count)")
    switch mode {
    case .singleThread:
        return chooseNextGuessSingleThread(untried: untried)
    case .multipleThreads:
        return chooseNextGuessMultipleThreads(untried: untried)
    case .metalComputeShader:
        return chooseNextGuessMetalComputeShader(untried: untried)
    }
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

func getTimestamp() -> String {
    let date = Date()
    let dateFormatter = DateFormatter()
    dateFormatter.timeStyle = .medium
    let dateString = dateFormatter.string(from: date)
    return dateString
}

func log(message: String) {
    print("[\(getTimestamp())] \(message)")
}

func usage() {
    fputs("Usage: Mastermind [\n", stderr)
    fputs("\t-st | --single-thread |\n", stderr)
    fputs("\t-mt | --multiple-threads |\n", stderr)
    fputs("\t-mcs | --metal-compute-shader\n", stderr)
    fputs("]\n", stderr)
    exit(1)
}

func processCommandLineArgs() {
    if CommandLine.argc < 2 {
        return
    }
    let arg1 = CommandLine.arguments[1]
    switch arg1 {
    case "-st", "--single-thread":
        mode = .singleThread
    case "-mt", "--multiple-threads":
        mode = .multipleThreads
    case "-mcs", "--metal-compute-shader":
        mode = .metalComputeShader
        fputs("--metal-compute-shader not implemented yet!\n", stderr)
        exit(1)
    default:
        usage()
    }
}

func main() {
    processCommandLineArgs()
    let secret = randomSecret()
    let answer = solve { guess in
        let score = evaluateScore(code1: secret, code2: guess)
        log(message: "guess: \(guess); score: \(score)")
        return score
    }
    log(message: "answer: \(answer)")
}

main()
