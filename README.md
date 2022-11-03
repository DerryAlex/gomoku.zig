## Gomoku.zig

A renju AI compatible with Gomoku Cup Protocol.

### User Interface

A simple wrapper to make the interface more friendly to human users. This can be slightly modified for self-training. UTF-8 enviroment is required to display normally.

(Run `make all` first.) Run `./manager ./human ./pbrain` to play as black. Run `./manager ./pbrain ./human` to play as white.

### How it works

`main.zig` reads the command and calls protocol parser. `protocol.zig` deals with the protocol and calls AI.

#### Libraries

`array.zig`: multidimensional array whose size is only known at runtime. This makes `[n][m]T` possible, where `n, m` is unknown at comptime.

`scanner.zig`: input helper as there is currently no formatted input in the Zig standard library.

`renju.zig`: forbidden move detection. (RIF rules)

#### AI

##### Fast evaluation in union jack area

```
x   x   x
 x  x  x
  x x x
   xxx
xxxx@xxxx
   xxx
  x x x
 x  x  x
x   x   x
```

2x`int8` can be used to represent the situation in one of the four directions. The bit map can be efficiently updated. Pre-calculate the shape("open four", "four", "open three", etc.) for 2^16 situations.

Simply combine the shape in four directions to get an evaluation. For example, score("two" + "open three" + "none" + "none") = score("two") + score("open three"), score("open three" + "open three" + "none" + "none") = special_score("open three" + "open three").

NOTE: This method cannot handle false forbidden moves and it ignores pieces outside the union jack area. To deal with forbidden moves, recursion is needed(as what `renju.zig` does). For the latter drawback, see the following example:

```
○┼┼┼┼
┼●○┼┼
┼┼●○●
┼┼┼●▲
┼┼┼┼┼
```

The triangle piece is only considered as a plain "open two".

##### NNUE



##### VCF & VCT

Check whether we can win by continuous threat. NOTE: This calls fast evaluation to decide whether it is a forbidden move. (You may want to replace it with `renju.checkLegal`)

##### Min-Max Search

If VCF and VCT do not work, do a min-max search. Alpha-beta pruning is applied. Iterative deepening and heuristic method is also used. The width for each node is almost hardwired to `8`.

### License

GPL v3