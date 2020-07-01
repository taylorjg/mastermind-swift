//
//  main.swift
//  Mastermind
//
//  Created by Administrator on 19/06/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

import Foundation
import Metal

let device = MTLCreateSystemDefaultDevice()!
let library = device.makeDefaultLibrary()!
let kernelFunction = library.makeFunction(name: "findBest")!
let commandQueue = device.makeCommandQueue()!
let pipelineState = try! device.makeComputePipelineState(function: kernelFunction)

enum Mode {
    case singleThread
    case multipleThreads
    case metalComputeShader
}

var mode: Mode = .singleThread

enum Peg: Int, CaseIterable, CustomStringConvertible {
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

func makeAllCodes() -> [Code] {
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

func makeAllScores() -> [Score] {
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

let allPegs: [Peg] = Peg.allCases
let allCodes: [Code] = makeAllCodes()
let allScores: [Score] = makeAllScores()

func countOccurrencesOfPeg(_ peg: Peg, in code: Code) -> Int {
    return
        (code.p0 == peg ? 1 : 0) +
            (code.p1 == peg ? 1 : 0) +
            (code.p2 == peg ? 1 : 0) +
            (code.p3 == peg ? 1 : 0)
}

func countMatchingPegsByPosition(code1: Code, code2: Code) -> Int {
    return
        (code1.p0 == code2.p0 ? 1 : 0) +
            (code1.p1 == code2.p1 ? 1 : 0) +
            (code1.p2 == code2.p2 ? 1 : 0) +
            (code1.p3 == code2.p3 ? 1 : 0)
}

func evaluateScore(code1: Code, code2: Code) -> Score {
    let minOccurrencies = allPegs.map { peg -> Int in
        let numOccurrencies1 = countOccurrencesOfPeg(peg, in: code1)
        let numOccurrencies2 = countOccurrencesOfPeg(peg, in: code2)
        return min(numOccurrencies1, numOccurrencies2)
    }
    let sumOfMinOccurrencies = minOccurrencies.reduce(0, +)
    let blacks = countMatchingPegsByPosition(code1: code1, code2: code2)
    let whites = sumOfMinOccurrencies - blacks
    return Score(blacks: blacks, whites: whites)
}

func randomSecret() -> Code {
    allCodes.randomElement()!
}

let initialGuess = Code(p0: .red, p1: .red, p2: .green, p3: .green)

func findBest(untried: [Code], chunk: [Code]) -> (Int, Code) {
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
    let best = findBest(untried: untried, chunk: allCodes)
    return best.1
}

func chooseNextGuessMultipleThreads(untried: [Code]) -> Code {
    let numThreads = 8
    if untried.count < numThreads {
        return chooseNextGuessSingleThread(untried: untried)
    }
    let chunkSize = allCodes.count / numThreads
    let chunks = allCodes.chunked(into: chunkSize)
    var bests = [(Int, Code)]()
    let dispatchQueue = DispatchQueue.global(qos: .userInitiated)
    let dispatchGroup = DispatchGroup()
    let dispatchSemaphore = DispatchSemaphore(value: 1)
    for chunk in chunks {
        dispatchQueue.async(group: dispatchGroup) {
            let best = findBest(untried: untried, chunk: chunk)
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
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let commandEncoder = commandBuffer.makeComputeCommandEncoder()!
    commandEncoder.setComputePipelineState(pipelineState)
    
    let untriedInterop = untried.map { code in encodeCodeInterop(code: code) }
    let untriedInteropLength = MemoryLayout<UInt16>.stride * untriedInterop.count
    commandEncoder.setBytes(untriedInterop, length: untriedInteropLength, index: 0)
    
    var untriedCount = UInt16(untriedInterop.count)
    let untriedCountLength = MemoryLayout<UInt16>.stride
    commandEncoder.setBytes(&untriedCount, length: untriedCountLength, index: 1)
    
    let numThreads = allCodes.count
    let bestsBufferLength = MemoryLayout<BestInterop>.stride * numThreads
    let bestsBuffer = device.makeBuffer(length: bestsBufferLength, options: .storageModeShared)!
    commandEncoder.setBuffer(bestsBuffer, offset: 0, index: 2)
    
    let threadsPerGrid = MTLSize(width: numThreads, height: 1, depth: 1)
    let threadsPerThreadgroup = MTLSize(width: pipelineState.threadExecutionWidth, height: 1, depth: 1)
    commandEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    
    commandEncoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    
    let bests = bestsBuffer.contents().bindMemory(to: BestInterop.self, capacity: numThreads)
    var best: BestInterop? = nil
    for index in 0..<numThreads {
        let bestInterop = (bests + index).pointee
        if best == nil || bestInterop.count < best!.count {
            best = bestInterop
        }
    }
    return decodeCodeInterop(encoded: best!.code)
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
    default:
        usage()
    }
}

func main() {
    processCommandLineArgs()
    let secret = randomSecret()
    log(message: "secret: \(secret)")
    let start = DispatchTime.now()
    let answer = solve { guess in
        let score = evaluateScore(code1: secret, code2: guess)
        log(message: "guess: \(guess); score: \(score)")
        return score
    }
    let end = DispatchTime.now()
    let duration = (end.uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    log(message: "answer: \(answer); duration: \(duration)ms")
}

main()
