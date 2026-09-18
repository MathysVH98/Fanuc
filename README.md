# FANUC TP toolkit

Tools for reading and writing FANUC teach-pendant program files: the binary `.TP`
format and the ASCII `.LS` listing format.

This exists because converting `.LS` -> `.TP` normally requires FANUC's own
translator (RoboGuide / WinOLPC `MakeTP`), or the **ASCII Upload** option
(R507) on the controller, which lets the controller compile a `.LS` on load.
Where neither is available, these tools do the translation directly.

## Layout

| path | purpose |
|---|---|
| `tp_tools/` | the codec: LZSS container, record framing, instruction + position encoding |
| `tests/` | round-trip and byte-identity gates |
| `fixtures/` | reference programs used as the test corpus |
| `docs/FORMAT.md` | byte-level description of the `.TP` format |

## Usage

```
./ls2tp.py TARGET.LS --reference REF.TP --out TARGET.TP
```

A reference `.TP` is required, and not merely as a convenience. `.LS` prints
positions to three decimals while the binary stores float32, so re-encoding a
point from text lands it on a neighbouring float32 — every one of the 240
values in the reference program shifts. Position records are therefore copied
from the reference rather than re-encoded, and the builder **refuses** to
synthesise a position that has no bit-exact twin there rather than silently
shifting a taught point.

## Status

See `docs/FORMAT.md` for exactly which parts of the format are confirmed
against a reference binary and which are inferred, and `docs/MN_SPEC.md` /
`docs/META_SPEC.md` for the byte-level detail.

## Validation

The codec is held to three gates:

1. **Decode gate** — decoding the reference `.TP` reproduces its `.LS` text.
2. **Byte-identity gate** — re-encoding that `.LS` reproduces the original
   `.TP` byte for byte.
3. **Round-trip gate** — for any input `.LS`, decoding the `.TP` we emit
   reproduces the input.

Gate 2 is the important one: it is the only check that proves the encoder
agrees with FANUC's, rather than merely agreeing with our own decoder. It
passes: `compress(decompress(PG21.TP)) == PG21.TP`, 4233 of 4233 bytes.

Run them with `for t in tests/test_*.py; do python3 "$t"; done`.

## Caveat

A file produced by these tools has not been through FANUC's translator.
Load it on a controller in **T1** with the program stepped, not in AUTO,
before trusting it.
