# FANUC .TP `/MN` section — byte-level instruction encoding

Scope: raw offsets `0x7F .. 0x1E96` of `PG21.tp.raw0`, i.e. the 550 program lines
that print as `PG21.LS` lines 34..583.  Derived by 1:1 alignment of the 550 binary
records against the 550 `.LS` lines.

Status of the deliverables:
* `mn_decode.py` reproduces `PG21.LS` lines 34..583 **byte-identically** (`cmp` clean,
  including CRLF and every trailing space).
* `mn_encode.py` reproduces `raw[0x7F:0x1E97]` with **549 / 550 records byte-exact**;
  the single failure is an unavoidable loss of precision in the `.LS` text itself
  (see §8).

---

## 0. CORRECTION to FINDINGS.md §1 — the LZSS ring buffer is prefilled with **0x00**

`FINDINGS.md` says the Okumura LZSS window is prefilled with `0x20`.  It is prefilled
with **`0x00`**.  This matters: 361 of the 9409 decompressed bytes change (278 of them
inside `/MN`), and with the wrong prefill the instruction encoding looks
non-deterministic — identical instructions appeared to encode differently
(`DO[24]=OFF` → `... 64 32 00 00` in one place and `... 64 32 20 20` in another),
`GO[10]=0` stored its zero as `0x20`, string terminators were sometimes `0x20`, and
`FINE` sometimes encoded as `0x20`.  All of that was the decompressor emitting `0x20`
for matches that reach into the never-written part of the ring buffer.

With prefill `0x00`:
* every one of those bytes becomes `0x00`;
* the record trailer byte is `0x00` for all 549 non-final records (was a mix of
  `0x00`/`0x20`);
* the header becomes NUL-padded, which is also self-evidently right:
  `50 47 32 31 00 00 ...` (`"PG21"` + NULs), `MNEDITOR\0`, `PICK HEAVY DUTY\0`.

Only the `0x00` prefill makes the format deterministic.  `PG21.tp.raw0` in this
directory is the corrected decompression; `tplib.decompress()` / `compress()` should
have `bytearray(b' '*N)` changed to `bytearray(N)`.

(Unrelated note for whoever owns the container: `tplib.compress()` with the corrected
prefill produces 4249 bytes vs. FANUC's 4233 — it decompresses correctly but is not a
byte-identical re-compression, because the match-selection heuristic differs.)

---

## 1. Record framing

```
record := <u8 len> <body[len]> <u8 term>          total size = len + 2
```

* `len` counts the body only — the opcode byte plus its operands.
* `term` is `0x00` for records 1..549.
* For record 550 the byte in the `term` slot is `0xFF`: it is the first byte of the
  `FF FF 03 00` section marker that introduces `/POS` at `0x1E96`.  (`/MN` itself is
  introduced by `FF FF 02 00` at `0x7B`.)  Two equivalent readings are possible —
  either the trailer is per-record and the last one is overlaid by the section
  marker, or the `0x00` is a *leading* byte of the following record and the `00` of
  `FF FF 02 00` is record 1's.  Both give identical bytes; I use the trailing reading.
* `len == 1` with body `FF` is a blank program line.

Opcode census over the 550 records (top level / after unwrapping the `//` wrapper 0x48):

| op | top-level | effective | meaning |
|----|----|----|----|
| `04` | 11 | 20 | `PR[..]=` assignment |
| `0F` | 46 | 66 | `DO[..]=` assignment |
| `17` | 2 | 2 | `GO[..]=` assignment |
| `1E` | 127 | 145 | `!` remark |
| `48` | 88 | – | `//` commented-out wrapper |
| `78` | 22 | 35 | `IF <cond>,<action>` |
| `7B` | 6 | 9 | `WAIT <t>(sec)` |
| `7C` | 18 | 21 | `WAIT <cond>` |
| `7E` | 15 | 19 | `JMP LBL[n]` |
| `80` | 22 | 26 | `LBL[n]` / `LBL[n:text]` |
| `81` | 7 | 11 | `CALL <prog>` |
| `87` | 15 | 17 | macro / instruction-table call |
| `95` | 6 | 6 | `PAYLOAD[n]` |
| `FE` | 39 | 47 | motion |
| `FF` | 126 | 126 | blank line |

---

## 2. Operands

Everything that is not an opcode is a small tagged operand.

### 2.1 Variable reference — `<type> 02 <u16 BE index>`

`02` is the "2-byte integer index follows" format code.

| type | class |
|----|----|
| `03` | `R[n]` (numeric register) |
| `04` | `PR[n]` (position register) |
| `0A` | `DI[n]` |
| `0F` | `DO[n]` |
| `17` | `GO[n]` |
| `7F` | `LBL[n]` reference |

`PR` may be followed by a **second** `02 <u16>` giving the element, which prints as
`PR[i,j]`.  The parser distinguishes "element present" from "next token is an
operator" by looking at the next byte: `0x02` → element, anything ≥ `0x64` → operator.

For `LBL` (both `7F` references and `80` definitions) bit `0x8000` of the 16-bit
number means the number is printed with a leading asterisk:

```
80 02 80 8C "LHTrlyBay1-4" 00      ->  LBL[*140:LHTrlyBay1-4]
                ^^^^ 0x808C = 0x8000 | 140
```

### 2.2 Literal constant — `01 <fmt> <data>`

| fmt | size | type |
|----|----|----|
| `01` | 1 | signed int8 |
| `02` | 4 | signed int32 BE |
| `03` | 4 | IEEE-754 float32 BE |

`fmt 02` is used only when the value does not fit in a signed byte (only instance in
this file: `177` → `01 02 00 00 00 B1`).  *Guess:* the 4-byte width for `fmt 02` is
inferred from that single instance; a 2-byte reading does not fit the record length.

### 2.3 Enumerated value — `32 <u8>`

`00` = `OFF`, `01` = `ON`, `07` = `LPOS`.  (Only these three occur here.)

### 2.4 String operand — `82 <bytes> 00`

Used by `CALL`.  Strings elsewhere (`LBL` text, `!` remark text, macro name) are
stored inline, NUL-terminated, with no `82` tag.

### 2.5 Operators

| byte | meaning |
|----|----|
| `64` | `=` (assignment) |
| `65` | `+` |
| `66` | `-` |
| `6B` | `=` (comparison) |
| `71` | `AND` |
| `72` | `OR` |

---

## 3. Instructions

### 3.1 Assignment — opcode **is** the LHS type byte (`04`, `0F`, `17`, …)

```
<lhs operand> 64 <rhs expression>
rhs expression := operand [ (65|66) operand ]*
```

```
08 17 02 00 0A 64 01 01 15      GO[10]=21
   |  |__________|  |  |______  const int8 21
   |  GO[10]        '='
07 0F 02 03 BA 64 32 01         DO[954]=ON
07 04 02 00 0A 64 32 07         PR[10]=LPOS
13 04 02 00 0A 02 00 03 64 04 02 00 0A 02 00 03 65 01 01 0A
   PR[10,3]                 =  PR[10,3]              +  10        -> PR[10,3]=PR[10,3]+10
18 04 02 00 0A 02 00 03 64 04 02 00 0A 02 00 03 65 03 02 00 01 66 01 01 4E
                                                   +  R[1]       -  78
                                                              -> PR[10,3]=PR[10,3]+R[1]-78
0E 04 02 00 0A 02 00 04 64 01 03 C3 33 E6 25        PR[10,4]=(-179.899)
0B 04 02 00 0A 02 00 05 64 01 01 FA                 PR[10,5]=(-6)
```

Rendering: a **negative** constant is wrapped in parentheses — `(-6)`, `(-179.899)` —
whether it is a direct assignment or not.  Positive constants and constants that
follow a `+`/`-` operator are printed bare.

### 3.2 Remark `1E` — `1E <text> 00`

```
0F 1E " MH PG21 - HD" 00        ->  ! MH PG21 - HD
```
Prints as `!` + the stored text verbatim (leading/trailing spaces in the text are kept).

### 3.3 Commented-out wrapper `48`

```
48 <complete body of the wrapped instruction>
```
The inner instruction's own `len` byte is dropped; the outer `len` = inner `len` + 1.
The printed line gets a `//` prefix.  This is the `//` flag asked about in the task —
it is a **wrapper opcode, not a bit**.

```
08 48 0F 02 00 18 64 32 01      ->  //DO[24]=ON
   ^^ wrapper, rest is exactly the body of `07 0F 02 00 18 64 32 01` = DO[24]=ON
```
Nesting is single-level in this file.

### 3.4 Blank line `FF` — body is the single byte `FF`, `len = 1`.

### 3.5 `JMP` `7E` — `7E <LBL operand>`

```
05 7E 7F 02 00 79               ->  JMP LBL[121]
```

### 3.6 `IF` `78` — `78 <condition> <action instruction body>`

The action is a complete instruction body (always a `JMP` here).

```
0D 78 0A 02 00 0D 6B 32 01 7E 7F 02 00 0D
      DI[13]     =  ON    | JMP LBL[13]           ->  IF DI[13]=ON,JMP LBL[13]

15 78 0A 02 00 43 6B 32 01 71 0A 02 00 4A 6B 32 01 7E 7F 02 00 0A
      DI[67]=ON           AND DI[74]=ON           JMP LBL[10]
                                        ->  IF DI[67]=ON AND DI[74]=ON,JMP LBL[10]
```

Condition grammar (n-ary, left to right, no precedence encoding):
```
condition := <operand> 6B <operand> [ (71|72) <operand> 6B <operand> ]*
```

### 3.7 `WAIT <cond>` `7C` — `7C <condition>` (same grammar)

```
08 7C 0A 02 00 5E 6B 32 01                      ->  WAIT DI[94]=ON
20 7C 0A 02 00 2B 6B 32 01 72 0A 02 00 2C 6B 32 01 72 0A 02 00 2D 6B 32 01 72 0A 02 00 2E 6B 32 01
                                     ->  WAIT DI[43]=ON OR DI[44]=ON OR DI[45]=ON OR DI[46]=ON
```

### 3.8 `WAIT <t>(sec)` `7B` — `7B 02 <u16 BE hundredths-of-a-second>`

```
04 7B 02 00 64      ->  WAIT   1.00(sec)      (0x0064 = 100)
04 7B 02 00 C8      ->  WAIT   2.00(sec)      (0x00C8 = 200)
```
Printed as `WAIT` + three spaces + `%.2f` + `(sec)`.

### 3.9 `LBL` definition `80` — `80 02 <u16 number> <text> 00`

```
05 80 02 00 09 00                        ->  LBL[9]                (empty text)
0E 80 02 00 21 "Loop Back" 00            ->  LBL[33:Loop Back]
12 48 80 02 80 8C "LHTrlyBay1-4" 00      ->  //LBL[*140:LHTrlyBay1-4]
```
Empty text prints as `LBL[n]`, non-empty as `LBL[n:text]`.  Trailing spaces inside the
text are preserved (`LBL[10:Skip Pickup ]`, `LBL[13:Return to Home ]`).

### 3.10 `CALL` `81` — `81 82 <name> 00`

```
0B 81 82 "CLP1_OPN" 00       ->  CALL CLP1_OPN
12 81 82 "VIS_RHPART_BAY1" 00 -> CALL VIS_RHPART_BAY1
```

### 3.11 Macro / instruction-table call `87`

```
87 <u8 id> <name> 00 [ 3D <u8 argcount> <operand>*argcount 40 ]
```

```
11 87 05 "GO TO HOME POS" 00                        ->  GO TO HOME POS
0F 87 06 "GO TO POUNCE" 00                          ->  GO TO POUNCE
13 87 03 "ENTER ZONE" 00 3D 01 01 01 01 40          ->  ENTER ZONE(1)
12 87 04 "EXIT ZONE" 00 3D 01 01 01 06 40           ->  EXIT ZONE(6)
```

* `id`: `03` = ENTER ZONE, `04` = EXIT ZONE, `05` = GO TO HOME POS, `06` = GO TO POUNCE.
  These are indices into this controller's macro table — they are **not** derivable
  from the name, so an encoder needs a per-controller table.  Decoding does not need
  them, because the name string is stored too.
* `3D` / `40` open and close the argument list; the byte after `3D` is the argument
  count.  *(Guess — consistent with all 8 argument-bearing records, all of which have
  count 1.)*
* With no argument list the line is just the name; with one it is `NAME(a,b,…)`.

### 3.12 `PAYLOAD` `95` — `95 01 00 02 <u16 BE n>`

```
06 95 01 00 02 00 01         ->  PAYLOAD[1]
06 95 01 00 02 00 03         ->  PAYLOAD[3]
```
`02 <u16>` is the ordinary 2-byte index form.  The `01 00` between the opcode and the
index is **unexplained**; it is constant across all 6 PAYLOAD records.
*Guess:* motion-group number 1 (`GP1`), plus a flag saying "do not print the group".

### 3.13 Motion `FE` — fixed 10-byte body

```
FE <mtype> <postype> <u16 posidx> <u16 speed> <spdunit> <termtype> <termval>
```

| field | values seen |
|----|----|
| `mtype` | `01` = `J`, `02` = `L` |
| `postype` | `00` = `P[..]`, `01` = `PR[..]` |
| `posidx` | u16 BE; **`0` prints as `P[...]`** (an untaught position) |
| `speed` | u16 BE |
| `spdunit` | `00` = `%`, `01` = `mm/sec` |
| `termtype` | `00` = `FINE`, `80` = `CNT` |
| `termval` | CNT value; `00` when `FINE` |

```
0A FE 01 00 00 26 00 64 00 00 00     ->  J P[38] 100% FINE
0A FE 01 00 00 0D 00 64 00 80 05     ->  J P[13] 100% CNT5
0A FE 02 00 00 21 02 EE 01 80 32     ->  L P[33] 750mm/sec CNT50
0A FE 02 01 00 0A 02 EE 01 00 00     ->  L PR[10] 750mm/sec FINE
0A FE 01 00 00 00 00 64 00 00 00     ->  J P[...] 100% FINE
```
Unit codes beyond `00`/`01` (`cm/min`, `inch/min`, `deg/sec`, `sec`, `msec`) and motion
types `C`/`A` are **assumed** from FANUC's documented TP vocabulary; they do not occur
in this file.

---

## 4. Text layout of a `/MN` line

```
"%4d:" + indent + text + extra_spaces + " ;"
```

* `indent` is `""` for an un-commented motion record (opcode `FE` at top level) and
  `"  "` (two spaces) for everything else — including a **commented-out** motion,
  which prints `"  //J P[23] …"`.
* `extra_spaces` is 3 for motion (`FE`), `WAIT <cond>` (`7C`), `CALL` (`81`),
  `PR` assignment (`04`) and an **argument-less** macro (`87` with no `3D` block);
  0 for everything else, including `ENTER ZONE(1)` (a macro *with* arguments).
  Together with the `" ;"` that is the familiar 4-trailing-spaces look.
* Line terminator in `PG21.LS` is CRLF.
* Blank line therefore renders as `"%4d:   ;"`.

---

## 5. Real-number printing

Float32 values are printed **truncated** (not rounded) to 3 decimals, then trailing
zeros and a trailing `.` are stripped, and a negative value is parenthesised:

| stored | exact value | printed |
|----|----|----|
| `C3 33 E6 25` | -179.8990020751953 | `(-179.899)` |
| `C0 0D 70 A4` | -2.2100000381469727 | `(-2.21)` |
| `43 33 E6 66` | 179.89999389648438 | `179.899` |

---

## 6. Worked full record examples

```
0x0139  15 78 0A 02 00 43 6B 32 01 71 0A 02 00 4A 6B 32 01 7E 7F 02 00 0A 00
        |  |  |______________| |  |  |______________| |  |  |___________| |
        |  IF  DI[67]        = ON AND DI[74]        = ON  JMP LBL[10]     term
        len=0x15=21 body bytes, total 23
        ->  "  10:  IF DI[67]=ON AND DI[74]=ON,JMP LBL[10] ;"

0x0199  06 95 01 00 02 00 01 00      ->  "  14:  PAYLOAD[1] ;"
0x01E6  11 87 05 47 4F 20 54 4F 20 48 4F 4D 45 20 50 4F 53 00 00
                 "GO TO HOME POS"                              ^^ name NUL  ^^ term
        ->  "  20:  GO TO HOME POS    ;"
0x0571  0A FE 01 00 00 26 00 64 00 00 00 00   ->  "  82:J P[38] 100% FINE    ;"
0x00D2  01 FF 00                              ->  "   4:   ;"
0x1E8A  08 17 02 00 0A 64 01 01 00 00         ->  " 549:  GO[10]=0 ;"
0x1E94  01 FF FF                              ->  " 550:   ;"   (trailer is the /POS marker)
```

---

## 7. Everything in `/MN` is accounted for

Every byte of all 550 records is consumed by the grammar above: `mn_decode.py`'s
parser asserts on every fixed byte it expects (`02`, `64`, `6B`, `40`, the `95 01 00 02`
prefix) and consumes each body exactly to `len`.  The full 7704-byte block
`raw[0x7F:0x1E97]` is regenerated from text by `mn_encode.py` with one byte different
(§8).

Items that are *described* but whose *meaning* is a guess, not a derivation:

1. `01 00` inside `PAYLOAD` (constant here; guessed to be the motion group).
2. `3D` / `40` as argument-list delimiters, and the byte after `3D` as an arg count
   (all 8 instances have count 1, so "count" is inferred, not proven).
3. `fmt 02` constants being 4-byte int32 (one instance).
4. The `87` macro ids (`03`..`06`) are controller-specific table indices.
5. Whether the `0x00` between records is a trailing byte of the record or a leading
   byte of the next one (§1) — byte-identical either way.
6. Speed-unit codes `02`..`06` and motion types `C`/`A` are assumed, not observed.
7. `0x82` is read as a "string operand" tag; it only ever appears in `CALL`.

Nothing else in `/MN` is unexplained.

---

## 8. The one record that does not round-trip

```
line 207:  //PR[10,4]=179.899
  in file: … 64 01 03 43 33 E6 66      = float32 179.89999389648438  (= float32(179.9))
  encoded: … 64 01 03 43 33 E6 25      = float32 179.8990020751953   (= float32(179.899))
```

This is **not** a gap in the spec — it is information the `.LS` file does not carry.
The stored value is exactly `float32(179.9)`; because FANUC *truncates* rather than
rounds when printing 3 decimals, it displays as `179.899`.  Both `float32(179.9)` and
`float32(179.899)` truncate to the string `179.899`, so the text is ambiguous and no
text-driven encoder can choose correctly.  (The negative twin on line 391,
`PR[10,4]=(-179.899)`, really is `float32(-179.899)` and round-trips fine.)

If byte-exact reproduction of *this* file is required, carry the original 4 bytes
through, or special-case it.  For the real goal — encoding `PG21T5FX.LS` — it only
matters if that file contains the same truncation-ambiguous literal.

---

## 9. Note for `PG21T5FX.LS`

All 599 of its `/MN` lines encode without error with `mn_encode.py`.  Eight of them are
non-canonical: motion lines that were un-commented by hand and kept the two-space
indent (`  81:  J P[23] 100% CNT50    ;` instead of `  81:J P[23] 100% CNT50    ;`).
The encoder accepts both; the decoder always emits the canonical FANUC form.
