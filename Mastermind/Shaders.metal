//
//  Shaders.metal
//  Mastermind
//
//  Created by Administrator on 21/06/2020.
//  Copyright © 2020 Jon Taylor. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

typedef enum {
    red = 0,
    green = 1,
    blue = 2,
    yellow = 3,
    black = 4,
    white = 5
} peg_t;

constant peg_t allPegs[] = {red, green, blue, yellow, black, white};

typedef struct {
    peg_t p0;
    peg_t p1;
    peg_t p2;
    peg_t p3;
} code_t;

typedef struct {
    uint8_t blacks;
    uint8_t whites;
} score_t;

bool operator==(thread const score_t& lhs, constant const score_t& rhs)
{
    return lhs.blacks == rhs.blacks && lhs.whites == rhs.whites;
}

typedef struct {
    uint16_t count;
    uint16_t code;
} best_t;

uint16_t encodeCodeInterop(thread const code_t& code) {
    uint16_t p0 = code.p0;
    uint16_t p1 = code.p1 << 4;
    uint16_t p2 = code.p2 << 8;
    uint16_t p3 = code.p3 << 12;
    return p0 | p1 | p2 | p3;
}

code_t decodeCodeInterop(uint16_t encoded) {
    peg_t p0 = static_cast<peg_t>(encoded & 0x000f);
    peg_t p1 = static_cast<peg_t>((encoded & 0x00f0) >> 4);
    peg_t p2 = static_cast<peg_t>((encoded & 0x0f00) >> 8);
    peg_t p3 = static_cast<peg_t>((encoded & 0xf000) >> 12);
    return code_t { p0, p1, p2, p3 };
}

code_t allCodeFromIndex(uint16_t index) {
    peg_t p0 = allPegs[index / 216 % 6];
    peg_t p1 = allPegs[index / 36 % 6];
    peg_t p2 = allPegs[index / 6 % 6];
    peg_t p3 = allPegs[index % 6];
    return code_t { p0, p1, p2, p3 };
}

constant score_t allScores[] = {
    score_t { .blacks = 0, .whites = 0 },
    score_t { .blacks = 0, .whites = 1 },
    score_t { .blacks = 0, .whites = 2 },
    score_t { .blacks = 0, .whites = 3 },
    score_t { .blacks = 0, .whites = 4 },
    score_t { .blacks = 1, .whites = 0 },
    score_t { .blacks = 1, .whites = 1 },
    score_t { .blacks = 1, .whites = 2 },
    score_t { .blacks = 1, .whites = 3 },
    score_t { .blacks = 2, .whites = 0 },
    score_t { .blacks = 2, .whites = 1 },
    score_t { .blacks = 2, .whites = 2 },
    score_t { .blacks = 3, .whites = 0 },
    score_t { .blacks = 4, .whites = 0 }
};

uint8_t countOccurrencesOfPeg(peg_t peg, thread const code_t& code)
{
    return
    (code.p0 == peg ? 1 : 0) +
    (code.p1 == peg ? 1 : 0) +
    (code.p2 == peg ? 1 : 0) +
    (code.p3 == peg ? 1 : 0);
}

uint8_t countMatchingPegsByPosition(thread const code_t& code1, thread const code_t& code2)
{
    return
    (code1.p0 == code2.p0 ? 1 : 0) +
    (code1.p1 == code2.p1 ? 1 : 0) +
    (code1.p2 == code2.p2 ? 1 : 0) +
    (code1.p3 == code2.p3 ? 1 : 0);
}

score_t evaluateScore(thread const code_t& code1, thread const code_t& code2)
{
    uint8_t sumOfMinOccurrences = 0;
    for (constant peg_t& peg: allPegs) {
        uint numOccurrences1 = countOccurrencesOfPeg(peg, code1);
        uint numOccurrences2 = countOccurrencesOfPeg(peg, code2);
        sumOfMinOccurrences += min(numOccurrences1, numOccurrences2);
    }
    uint8_t blacks = countMatchingPegsByPosition(code1, code2);
    uint8_t whites = sumOfMinOccurrences - blacks;
    return score_t { blacks, whites };
}

kernel void findBest(constant uint16_t* untried [[buffer(0)]],
                     constant uint16_t& untriedCount [[buffer(1)]],
                     device best_t* bests [[buffer(2)]],
                     uint index [[thread_position_in_grid]])
{
    code_t allCode = allCodeFromIndex(index);
    uint16_t maxCount = 0;
    for (constant score_t& allScore: allScores) {
        uint16_t count = 0;
        for (uint i = 0; i < untriedCount; ++i) {
            code_t untriedCode = decodeCodeInterop(untried[i]);
            score_t score = evaluateScore(allCode, untriedCode);
            if (score == allScore) count++;
        }
        maxCount = max(maxCount, count);
    }
    bests[index] = best_t { maxCount, encodeCodeInterop(allCode) };
}
