# LZSS compressor for FANUC .TP — notes

Owner: LZSS worker.  Files owned: `okumura.py`, `LZSS_NOTES.md`.

## VERDICT: BYTE-IDENTITY **ACHIEVED**

    okumura.compress(PG21.tp.raw0)  ==  PG21.TP        # 4233 / 4233 bytes
    differing bytes: 0        first differing offset: n/a

`PG21.tp.raw0` is the 9409-byte payload obtained by decoding `PG21.TP` with the
ring prefilled with **0x00** (not 0x20).  The 8-byte container header
(`FE EF`, u16BE version=1, u32BE size=0x24C1) is produced by `compress()` and is
included in the comparison above.

## The algorithm

Haruhiko Okumura's public-domain `lzss.c` (1989) `Encode()`, ported line for line,
with `N=4096`, `F=18`, `THRESHOLD=2` and the ring prefilled with `0x00`.

The match finder is Okumura's binary search tree (`lson` / `rson` / `dad`,
`InsertNode` / `DeleteNode`).  Its tie-breaking is an emergent property of the BST
walk — it is *not* "most recent", "lowest offset" or "longest wins".  A naive
exhaustive greedy-longest-match encoder round-trips correctly but produces a
different (and here even slightly smaller) stream, so the BST is load-bearing.

Details that matter and are reproduced exactly:
* `text_buf[N + F - 1]`, zero-initialised; prefill `text_buf[0 .. N-F-1] = 0x00`.
* `s = 0`, `r = N - F = 4078`; priming read of up to `F` bytes into `text_buf[r..]`.
* `for (i = 1; i <= F; i++) InsertNode(r - i);` — **descending** order — then `InsertNode(r)`.
* `InsertNode` sets `match_position`/`match_length` from the nodes compared on the
  way down, updating only on **strictly greater** `i`, and splices node `p` out,
  replacing it with `r`, when the strings are identical for all `F` bytes.
* Main loop: `if (match_length > len) match_length = len;`, literal iff
  `match_length <= THRESHOLD`, `DeleteNode(s)` before `InsertNode(r)`, the
  `text_buf[s + N] = c` extension for `s < F-1`, the `while (i++ < last_match_length)`
  tail that decrements `len` and the final partial `code_buf` flush.

## The blocker that was NOT an algorithm problem

The first attempt used the earlier `FILL = 0x20` assumption and the corresponding
`PG21.tp.raw` decode.  That produced a *correct but not identical* stream and a
first divergence at stream offset 0x64.  A lockstep comparison against the
reference (forcing the reference's decisions and recording where the encoder
would have chosen differently) showed only **15 disagreeing decisions out of
~2000** — and two of them were provably impossible for *any* BST variant
(same match position, length exactly one byte short of the maximum achievable).
That impossibility was the signature of a wrong window, not a wrong encoder.

With `FILL = 0x00` and the `raw0` payload the same code gives **0 disagreements**.

Measured cross-check of all four fill/payload combinations (diff = differing bytes
vs. `PG21.TP`, container included):

| payload | encoder FILL | output size | differing bytes | first diff | identical |
|---|---|---|---|---|---|
| `PG21.tp.raw0` (0x00 decode) | **0x00** | **4233** | **0** | — | **YES** |
| `PG21.tp.raw` (0x20 decode)  | 0x20 | 4230 | 4004 | 0x6C | no |
| `PG21.tp.raw0`               | 0x20 | 4234 | 4083 | 0x11 | no |
| `PG21.tp.raw`                | 0x00 | 4233 | 2898 | 0x11 | no |

So both the payload *and* the encoder prefill must be 0x00.

## Variant search (task item 3)

384 combinations of 8 structural/semantic variants were scored by the number of
disagreeing match decisions in a lockstep replay against `PG21.TP`.
10 of the 384 reach 0 disagreements; they differ only in flags that are provably
no-ops on this input.  Flipping a single flag away from canonical:

| flag flipped | disagreements | stream bytes | identical |
|---|---|---|---|
| CANONICAL | 0 | 4225 | yes |
| `cmp >= 0` -> `cmp > 0` in the descent | 0 | 4225 | yes (no-op here: `cmp==0` only when all F bytes match, which breaks out first) |
| `DeleteNode(s)` index +/-1 | 0 | 4225 | yes (no-op: the node is deleted anyway one step later/earlier) |
| `InsertNode(r)` before `DeleteNode` | 0 | 4225 | yes (no-op here) |
| `i > match_length` -> `i >= match_length` | 346 | 4225 | **no** |
| omit the `InsertNode` node-splice | 119 | 4239 | **no** |
| omit the `match_length >= F` break | 108 | 4225 | **no** |
| skip the F priming `InsertNode(r-i)` calls | 9 | 4226 | **no** |
| priming inserts ascending instead of descending | 8 | 4225 | **no** |

Also tested and rejected earlier (all strictly worse or no-ops): capping
`match_length` at the remaining length, literal at `match_length < THRESHOLD`
instead of `<=`, signed byte comparison, comparison-loop bound `F+1`,
`match_length` initialised to `THRESHOLD`, prefilling the whole ring including the
`text_buf[N..N+F-2]` extension.

So the load-bearing details are: strict `>` on the match update, the node-splice,
the `>= F` break, and the F+1 priming insertions in descending order.

## Round-trip verification (task item 4)

`python3 okumura.py` runs the suite.  Latest run:

    PG21: mine=4233 ref=4233 differing_bytes=0 IDENTICAL=True
    round-trip cases: 19, failures: 0

The 19 cases are `PG21.tp.raw0` truncated to 0, 1, 2, 17, 18, 19, 100, 4095, 4096,
4097, 5000, 9408 and 9409 bytes (exercising the empty input, the priming read, and
both sides of the ring wrap), the empty string, 70000 zero bytes (multi-wrap,
maximal-match heavy), 5000 random bytes (literal heavy), and `PG21.tp.raw0` with
3 / 300 / 3000 random byte mutations.  All decompress back to the exact input.

Two further independent payloads, compressed and round-tripped:

    PG21.LS      22160 -> 7454 bytes (33.6%)  round-trip OK
    PG21T5FX.LS  23799 -> 8594 bytes (36.1%)  round-trip OK

NOTE for other workers: `tplib.decompress()` still prefills the ring with 0x20 and
therefore does **not** round-trip against this encoder.  `okumura.decompress()` is
the 0x00 version and is what the self-test uses.  I did not modify `tplib.py`.

## API

    okumura.compress(raw, version=1) -> bytes   # 8-byte header + LZSS stream
    okumura.compress_stream(raw)     -> bytes   # stream only
    okumura.decompress(data)         -> (payload, version)   # self-check helper
    okumura.FILL = 0x00                          # ring prefill byte
