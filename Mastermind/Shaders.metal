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

typedef struct {
    uint16_t count;
    uint16_t code;
} best_t;

uint16_t encodeCodeInterop(code_t code) {
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

kernel void test(constant uint16_t *untried [[buffer(0)]],
                 constant uint16_t &untriedCount [[buffer(1)]],
                 device best_t *bests [[buffer(2)]],
                 uint index [[thread_position_in_grid]])
{
    code_t allCode = allCodeFromIndex(index);
    bests[index].count = index;
    bests[index].code = encodeCodeInterop(allCode);
}
