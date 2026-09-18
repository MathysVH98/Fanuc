# FANUC `.TP` binary format

Derived by reverse-engineering `fixtures/PG21.TP` against `fixtures/PG21.LS`,
which are the same program in the two formats. Every claim below is marked
**CONFIRMED** (verified against the reference pair) or **INFERRED**.

## 1. Container — LZSS  *(CONFIRMED)*

A `.TP` file is an 8-byte header followed by an LZSS-compressed payload.

| offset | size | field |
|---|---|---|
| 0 | 2 | magic `FE EF` |
| 2 | 2 | version, big-endian u16 (`0x0001`) |
| 4 | 4 | uncompressed payload size, big-endian u32 |
| 8 | .. | LZSS stream |

The stream is Haruhiko Okumura's classic LZSS:

- ring buffer `N = 4096`, **prefilled with `0x00`**

  Okumura's original `lzss.c` prefills with `0x20` (space); FANUC deviated. This is
  easy to get wrong because the program-name field *looks* space-padded under a space
  fill — but that padding is produced *by* the fill, so inferring it that way is
  circular. The decisive case is `PG21.LS` line 549, `GO[10]=0`:

  | fill | record bytes | value operand |
  |---|---|---|
  | `0x00` | `08 17 02 00 0A 64 01 01 `**`00`**` 00` | 0 — correct |
  | `0x20` | `08 17 02 00 0A 64 01 01 `**`20`**` 00` | 32 — wrong |

  361 of the 9409 payload bytes differ between the two decodes, every one of them
  `0x20` vs `0x00`.

- max match `F = 18`, `THRESHOLD = 2`
- write cursor starts at `r = N - F = 4078`
- a flag byte precedes each group of 8 items, read **LSB-first**
  - bit `1` -> one literal byte
  - bit `0` -> two bytes `b1 b2`:
    `offset = b1 | ((b2 & 0xF0) << 4)`, `length = (b2 & 0x0F) + 3`

`PG21.TP` is 4233 bytes and decompresses to exactly the 9409 bytes its header
declares.

## 2. Record framing  *(CONFIRMED)*

The `/MN` program body begins at payload offset `0x7F`. Each program line is
one record:

```
record := <u8 len> <body: len bytes> <u8 terminator>
total record size = len + 2
```

`len` counts the opcode and its operands only. The terminator is `0x00` for
records 1..549. Record 550's terminator slot holds `0xFF` — the first byte of
the `FF FF 03 00` marker that begins `/POS`, mirroring `FF FF 02 00` at `0x7B`
before `/MN`.

A record with `len = 1` is a blank program line (`  ;`).

Worked example — `GO[10]=21`:

```
08 | 17 02 00 0A 64 01 01 15 | 00
^    ^  ^     ^  ^  ^        ^
|    |  |     |  |  |        terminator
|    |  |     |  |  literal int8 operand, value 21
|    |  |     |  assign operator
|    |  |     GO index 10
|    |  variable-reference tag
|    opcode 0x17 = GO assignment
len = 8
```

Parsing `PG21.TP` from `0x7F` yields exactly **550 records**, ending exactly at
the `/POS` boundary — matching `LINE_COUNT = 550`. Records map 1:1 and in order
onto `/MN` lines 1..550.

### Opcode census over those 550 records

| opcode | count | meaning |
|---|---|---|
| `0x1E` | 127 | comment |
| — | 126 | blank line (`len`=1) |
| `0x48` | 88 | |
| `0x0F` | 46 | |
| `0xFE` | 39 | |
| `0x00` | 33 | |
| `0x78` | 22 | conditional (`IF ... JMP`) |
| `0x80` | 22 | |
| `0x7C` | 18 | |
| `0x87` | 15 | |
| `0x7E` | 15 | |
| `0x81` | 7 | |
| `0x7B` | 6 | |
| `0x95` | 6 | |
| `0x17` | 2 | group-output assignment (`GO[n]=v`) |

## 3. Payload section layout  *(CONFIRMED boundaries)*

| range | section |
|---|---|
| `0x0000`..`0x007A` | header / `/ATTR` (program name at `0x04`, space-padded; `OWNER`, `COMMENT`, timestamps) |
| `0x007B`..`0x007E` | boundary marker `FF FF 02 00` |
| `0x007F`..`0x1E96` | `/MN` — 550 instruction records |
| `0x1E97`..`0x246D` | `/POS` — position records, terminated `FF FF` |
| `0x246E`..`0x24C0` | trailing `/APPL`-equivalent block (`WNHD`, `SGLYAV`, `SPOT`, `MUAP`, `LANG`) and `FILE_NAME` |

Note the trailing block stores `PG14`, which is the `FILE_NAME` field of
`PG21.LS` — not its program name. The two differ in the reference file.
