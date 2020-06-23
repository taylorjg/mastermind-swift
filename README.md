# Description

Swift implementation of Knuth's algorithm to solve Mastermind within 5 guesses.

# TODO

* ~~Modes of operation:~~
  * ~~using a single thread~~
  * ~~using multiple threads~~
  * ~~using a Metal compute shader~~

# Results

Here are typical results for each mode on my MacBook Pro (Mid 2014). The GPU mode is unbelievably quick!

## Using a single thread

Execution time: about 2 mins 55 seconds.

```
$ Mastermind --single-thread
[23:36:22] secret: Y-w-w-Y
[23:36:22] guess: R-R-G-G; score:
[23:36:22] untried.count: 256
[23:39:05] guess: B-B-Y-b; score: W
[23:39:05] untried.count: 16
[23:39:15] guess: w-w-Y-w; score: BWW
[23:39:15] untried.count: 3
[23:39:17] guess: R-Y-R-w; score: WW
[23:39:17] guess: Y-w-w-Y; score: BBBB
[23:39:17] answer: Y-w-w-Y
```

## Using multiple threads

Execution time: about 1 min 13 seconds.

```
$ Mastermind --multiple-threads
[23:40:37] secret: b-B-w-b
[23:40:37] guess: R-R-G-G; score:
[23:40:37] untried.count: 256
[23:41:35] guess: b-Y-B-B; score: BW
[23:41:35] untried.count: 46
[23:41:46] guess: b-Y-Y-b; score: BB
[23:41:46] untried.count: 6
[23:41:50] guess: R-b-Y-w; score: WW
[23:41:50] guess: b-B-w-b; score: BBBB
[23:41:50] answer: b-B-w-b
```

## Using a Metal compute shader

Execution time: about 1 second.

```
$ Mastermind --metal-compute-shader
[23:46:36] secret: b-w-G-b
[23:46:36] guess: R-R-G-G; score: B
[23:46:36] untried.count: 256
[23:46:36] guess: R-B-Y-Y; score:
[23:46:36] untried.count: 16
[23:46:36] guess: R-b-G-b; score: BBW
[23:46:36] untried.count: 2
[23:46:36] guess: R-R-R-b; score: B
[23:46:36] guess: b-w-G-b; score: BBBB
[23:46:36] answer: b-w-G-b
```

# Links

* [Mastermind (board game)](https://en.wikipedia.org/wiki/Mastermind_(board_game))
* [Five-guess algorithm](https://en.wikipedia.org/wiki/Mastermind_(board_game)#Worst_case:_Five-guess_algorithm)
* [Knuth's mastermind algorithm](https://math.stackexchange.com/questions/1192961/knuths-mastermind-algorithm)
* [knuth-mastermind.pdf](https://www.cs.uni.edu/~wallingf/teaching/cs3530/resources/knuth-mastermind.pdf)
