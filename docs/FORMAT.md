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

Sections are introduced by a 3-byte marker `FF FF <u8 id>` and contain a chain
of records:

```
marker := FF FF <id>            id 01 = /ATTR, 02 = /MN, 03 = /POS, 04 = trailer
record := <u16BE len> <body>
```

Only the `u16BE` reading closes exactly on the next marker in **both** `/MN` and
`/POS`:

| section | framing tried | records | chain ends |
|---|---|---|---|
| `/MN` | `u16BE len` from `0x7E` | 550 | `0x1E96` — exactly the `FF FF 03` marker |
| `/MN` | `u8 len`+2 from `0x7F` | 550 | `0x1E97` — one past it |
| `/POS` | `u16BE len` from `0x1E99` | 40 | `0x246D` — exactly the `FF FF 04` marker |
| `/POS` | `u8 len`+2 from `0x1E9A` | 40 | `0x246E` — one past it |

For records of 255 bytes or fewer the two readings describe the *same byte
stream*, shifted by one. The `u16BE` model is the correct one: what looks like a
trailing `0x00` terminator is really the **high byte of the next record's
length**, which is why it is always zero, and why the byte after it carries real
operands.

A record with `len = 1` is a blank program line (`  ;`).

Worked example — `GO[10]=21`:

```
00 08 | 17 02 00 0A 64 01 01 15
^       ^  ^     ^  ^  ^
|       |  |     |  |  literal int8 operand, value 21
|       |  |     |  assign operator
|       |  |     GO index 10
|       |  variable-reference tag
|       opcode 0x17 = GO assignment
u16BE length = 8
```

Parsing `PG21.TP` yields exactly **550** `/MN` records and **40** `/POS`
records, matching `LINE_COUNT = 550` and the program's declared points. Records
map 1:1 and in order onto `/MN` lines 1..550.

## 2b. Header, positions and trailer  *(CONFIRMED)*

Header fields, all reproducing `PG21.LS` exactly: program name at `0x04` (36
bytes, NUL-padded), `OWNER` at `0x2F`, `COMMENT` at `0x39`, `PROG_SIZE` u32BE at
`0x4B`, `CREATE` at `0x4F`, `MODIFIED` at `0x53`, `LINE_COUNT` u32BE at `0x5B`,
`MEMORY_SIZE` u32BE at `0x5F`.

**Timestamps are MS-DOS/FAT packing**, date word first, big-endian u32.
`5B18 A9C4` -> 2025-08-24 21:14:08. Seconds have 2-second granularity.

**There is no checksum anywhere** — not in the LZSS header, not in the payload,
not in the trailer. An encoder never has to compute one.

Position records: `<u16BE len>` (`0x24` cartesian, `0x20` joint), then position
number u16BE, group, a 4-byte kind descriptor, a UF/UT byte (`0x11` = UF1/UT1),
six **big-endian** IEEE-754 float32, and for cartesian points four config bytes
whose first three are the turn numbers as int8. **Cartesian values are mm and
degrees; joint values are radians.**

`PROG_SIZE` and `MEMORY_SIZE` are stored but could not be derived from file
content from a single sample.

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
