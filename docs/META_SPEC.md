# FANUC .TP binary — header / /POS / /APPL specification

Source of truth: **`PG21.tp.raw0`** — the LZSS decode of `PG21.TP` with the ring buffer
prefilled with **0x00** (9409 = 0x24C1 bytes), cross-checked against `PG21.LS`.
`PG21.tp.raw` (0x20 prefill) is stale and is NOT used here.

Scope: everything except the /MN instruction body.  The /MN body is 0x007E..0x1E95.

Labels: **[C]** confirmed (reproduces a value printed in PG21.LS, or structurally forced) ·
**[G]** guess · **[?]** unexplained (bytes are preserved verbatim by the codec).

---

## 0. Global container grammar  [C]

One grammar covers /ATTR, /MN and /POS:

```
section marker : FF FF <u8 section_id>
record         : <u16BE len> <len bytes of body>      (total on disk = len + 2)
```

/APPL uses its own record header, and the file ends with a bare `FF FF`:

```
/APPL record   : <u16BE block_idx> <u16BE sub_idx> <u8 len> <len bytes of body>
end of file    : FF FF
```

Measured section boundaries in `PG21.tp.raw0`:

| offset | bytes | meaning |
|---|---|---|
| 0x0000 | `00 00 03 00` | file preamble **[?]** |
| 0x0004 | 36 bytes | program name, NUL-padded |
| 0x0028 | `00 00` | name terminator / reserved **[?]** |
| 0x002A | `FF FF 01` | /ATTR marker, then one record of len 0x004C |
| 0x007B | `FF FF 02` | /MN marker, then 550 records |
| 0x1E96 | `FF FF 03` | /POS marker, then 40 records |
| 0x246D | `FF FF 04` | /APPL marker, then 7 records |
| 0x24BF | `FF FF` | EOF |

**Framing note (correction to two earlier descriptions).**  Measured, on `PG21.tp.raw0`:

```
/MN  as <u16BE len> from 0x007E : 550 records, chain ends at 0x1E96  == the FF FF 03 marker
/MN  as <u8 len>+2  from 0x007F : 550 records, chain ends at 0x1E97  == one byte past it
/POS as <u16BE len> from 0x1E99 :  40 records, chain ends at 0x246D  == the FF FF 04 marker
/POS as <u8 len>+2  from 0x1E9A :  40 records, chain ends at 0x246E  == one byte past it
```

Only the u16BE reading closes exactly on the next marker in *both* sections, so the marker is
**3 bytes** (`FF FF <id>`) and the byte that looked like a 4th marker byte / a record
"terminator" is really the **high byte of the next record's u16BE length**.  This also explains
the "2-byte tail carrying operands" in /MN: tail[0] is the last byte of the record body, and
tail[1] is always 0x00 because it is the next length's high byte.  (Both readings produce the
same byte stream for records ≤ 255 bytes; only the u16BE one is internally consistent and only
it can express a longer record.)

All multi-byte integers are **big endian**.  **0x00 is the filler/"unset" byte**; fixed-width
strings are NUL-padded.

---

## 1. Section A — preamble + program name + /ATTR  (0x0000 .. 0x007D)

```
00000000  00 00 03 00 50 47 32 31  00 00 00 00 00 00 00 00  |....PG21........|
00000010  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000020  00 00 00 00 00 00 00 00  00 00 ff ff 01 00 4c 4d  |..............LM|
00000030  4e 45 44 49 54 4f 52 00  00 50 49 43 4b 20 48 45  |NEDITOR..PICK HE|
00000040  41 56 59 20 44 55 54 59  00 00 00 00 00 32 9c 5b  |AVY DUTY.....2.[|
00000050  18 a9 c4 5d 31 30 35 00  00 00 00 00 00 02 26 00  |...]105.......&.|
00000060  00 35 50 00 01 00 00 00  32 00 00 00 00 00 00 00  |.5P.....2.......|
00000070  00 00 01 00 00 00 00 01  00 00 00 ff ff 02        |..............|
```

### 1.1 Byte map

| offset | len | bytes | field | status |
|---|---|---|---|---|
| 0x0000 | 4 | `00 00 03 00` | file preamble; **[G]** `u16BE 0` reserved + `u8 3` format version + `u8 0` pad | **[?]** |
| 0x0004 | 36 | `"PG21"` + 32 NUL | **program name**, ASCII, NUL-padded | **[C]** |
| 0x0028 | 2 | `00 00` | terminator / reserved (may be part of a 38-byte name field) | **[?]** |
| 0x002A | 3 | `FF FF 01` | /ATTR section marker | **[C]** |
| 0x002D | 2 | `00 4C` | u16BE record length = **76**; 0x2F + 76 = 0x7B = next marker | **[C]** |
| 0x002F | 8 | `"MNEDITOR"` | **OWNER**, ASCII, NUL-padded | **[C]** |
| 0x0037 | 2 | `00 00` | terminator / reserved | **[?]** |
| 0x0039 | 18 | `"PICK HEAVY DUTY"` + 3 NUL | **COMMENT**, ASCII, NUL-padded | **[C]** |
| 0x004B | 4 | `00 00 32 9C` | **PROG_SIZE** u32BE = **12956** | **[C]** |
| 0x004F | 4 | `5B 18 A9 C4` | **CREATE** timestamp | **[C]** |
| 0x0053 | 4 | `5D 31 30 35` | **MODIFIED** timestamp | **[C]** |
| 0x0057 | 4 | `00 00 00 00` | unused / zero-valued attribute slot | **[?]** |
| 0x005B | 4 | `00 00 02 26` | **LINE_COUNT** u32BE = **550** | **[C]** |
| 0x005F | 4 | `00 00 35 50` | **MEMORY_SIZE** u32BE = **13648** | **[C]** |
| 0x0063 | 24 | `00 01 00 00 00 32 00 …` | TCD / VERSION / PROTECT / DEFAULT_GROUP / CONTROL_CODE / LOCAL_REGISTERS area — see §1.4 | mostly **[?]** |
| 0x007B | 3 | `FF FF 02` | /MN section marker | **[C]** |

The /ATTR record body is 0x002F..0x007A = 76 bytes, exactly the declared length.

### 1.2 Field-width ambiguity (honest caveat)

Because every numeric high half is zero, two readings are byte-identical:

* **(a)** used by the codec: `PROG_SIZE`/`LINE_COUNT`/`MEMORY_SIZE` are **u32BE** at 0x4B/0x5B/0x5F
  and COMMENT is 18 bytes (0x39..0x4A).
* **(b)** also consistent: `00 00` is a 2-byte string terminator, the numbers are **u16BE** at
  0x4D/0x5D/0x61, COMMENT is 16 bytes (the FANUC maximum) at 0x39..0x48, and then the `00 00`
  at 0x5B is **VERSION = 0**.

Nothing in the PG21 → PG21T5FX job distinguishes them (all three numbers still fit in a u16, and
both the old and new comments are 15 characters).  **Constraint from reading (b): do not write a
COMMENT longer than 16 characters without re-testing** — under (a) a 17–18 char comment would
silently overwrite the PROG_SIZE high half.

### 1.3 Date/time packing  [C — both timestamps reproduced exactly]

One **32-bit big-endian** word = `(dos_date << 16) | dos_time`, i.e. MS-DOS/FAT packing with the
**date word first**:

```
dos_date : bits 15..9 year-1980   bits 8..5 month(1-12)   bits 4..0 day(1-31)
dos_time : bits 15..11 hour       bits 10..5 minute       bits 4..0 second/2
```

```
CREATE   = 5B 18 A9 C4
  0x5B18 = 0101101 1000 11000 -> 1980+45=2025, month 8, day 24
  0xA9C4 = 10101 001110 00100 -> 21h 14m 4*2=8s
  => DATE 25-08-24  TIME 21:14:08     == PG21.LS

MODIFIED = 5D 31 30 35       (NOT the ASCII text "105" — that was a red herring)
  0x5D31 = 0101110 1001 10001 -> 1980+46=2026, month 9, day 17
  0x3035 = 00110 000001 10101 -> 6h 1m 21*2=42s
  => DATE 26-09-17  TIME 06:01:42     == PG21.LS
```

The .LS prints the year mod 100.  Seconds have 2-second granularity.

### 1.4 The 24 bytes at 0x0063..0x007A

```
      63 64 65 66 67 68 69 6a 6b 6c 6d 6e 6f 70 71 72 73 74 75 76 77 78 79 7a
      00 01 00 00 00 32 00 00 00 00 00 00 00 00 00 01 00 00 00 00 01 00 00 00
```

Only **four non-zero bytes**: `0x64 = 1`, `0x68 = 0x32 = 50`, `0x72 = 1`, `0x77 = 1`.

These 24 bytes must carry: `VERSION = 0`, `PROTECT = READ_WRITE`,
`TCD: STACK_SIZE 0, TASK_PRIORITY 50, TIME_SLICE 0, BUSY_LAMP_OFF 0, ABORT_REQUEST 0,
PAUSE_REQUEST 0`, `DEFAULT_GROUP = 1,*,*,*,*`, `CONTROL_CODE = 00000000 00000000`,
`LOCAL_REGISTERS = 0,0,0`.

* `0x68 = 50` is the **only** byte in the whole file equal to 50 and TASK_PRIORITY is the only
  attribute with value 50 ⇒ **TASK_PRIORITY**, **[G]** but high confidence.
* The three `0x01` bytes at 0x64, 0x72, 0x77 correspond to the attributes whose value is 1 or
  "enabled" (`DEFAULT_GROUP` group-1 and two others, most plausibly `PROTECT = READ_WRITE` and a
  group-mask).  **I cannot assign them individually from a single sample.** **[?]**
* Every other attribute in this list has value 0, so any zero byte here is consistent with any
  placement — the layout is genuinely underdetermined.

**Practical consequence: none for this job.**  `PG21T5FX.LS` declares the same VERSION, PROTECT,
TCD, DEFAULT_GROUP, CONTROL_CODE and LOCAL_REGISTERS, so these 24 bytes are copied verbatim.

### 1.5 PROG_SIZE / MEMORY_SIZE / LINE_COUNT / CHECKSUM

* **LINE_COUNT is stored**: u32BE(0x5B) = 550, and 550 /MN records parse independently. **[C]**
* **PROG_SIZE is stored**: u32BE(0x4B) = 12956. **[C]**
* **MEMORY_SIZE is stored**: u32BE(0x5F) = 13648. **[C]**
* **Neither PROG_SIZE nor MEMORY_SIZE could be derived from the file content.**  They are not the
  raw size (9409) nor the compressed size (4233).  Relations I tried and rejected:
  `raw`, `raw + k·LINE_COUNT`, `/MN bytes + /POS bytes + k`, `MEMORY_SIZE − PROG_SIZE = 692`
  (no meaning found).  One sample is not enough. **[?]**
* **THERE IS NO CHECKSUM ANYWHERE.**  Evidence:
  1. Every byte of section A is a string, a known integer, a timestamp, zero filler, or one of the
     four non-zero bytes in §1.4 — no full-range 16/32-bit quantity exists besides the two
     timestamps.
  2. The LZSS container header is `FE EF`, u16BE version, u32BE uncompressed size, then the bit
     stream; decompression consumes `PG21.TP` exactly, leaving no trailer.
  3. The payload ends `… 00 00 FF FF` at 0x24BF and stops — no trailing field.

  **A re-encoder therefore never has to compute a checksum.**

---

## 2. Section B — /POS  (0x1E96 .. 0x246C)

`FF FF 03` at 0x1E96, then 40 records; the chain ends exactly at 0x246D (`FF FF 04`).

### 2.1 Record layout  [C]

```
<u16BE len>                    len = 0x0024 (36) cartesian | 0x0020 (32) joint
  +0   u16BE  position number
  +2   u8     group number             0x01 = GP1
  +3   u8     0x00                     constant
  +4   u8     0x20 (cart) / 0x1C (joint)   == len - 4  (bytes from here to end of record) [G]
  +5   u8     0x12 (cart) / 0x19 (joint)   representation code                            [?]
  +6   u8     0x00 (cart) / 0x30 (joint)                                                  [?]
  +7   u8     0x11  = (UF << 4) | UT       UF = 1, UT = 1                                 [G]
  +8   6 x float32 BE                  see 2.2
  +32  3 x int8 + 1 byte               CARTESIAN ONLY: CONFIG, see 2.3
```

Bytes +3..+6 are constant per kind across all 40 records, so cartesian/joint can equally be
discriminated by record length (36 vs 32).  The `+4 == len-4` relation holds for both kinds but
rests on only two distinct values, hence **[G]**.

### 2.2 Float format  [C — verified against all 240 values in PG21.LS]

**IEEE-754 binary32, BIG ENDIAN.**  Little-endian is decisively wrong (gives values like
−4.5e23).  Units depend on the record kind:

* **CARTESIAN** — `X, Y, Z` in **millimetres**, `W, P, R` in **DEGREES**.
* **JOINT** — `J1..J6` in **RADIANS** (the .LS prints degrees).

All 240 decoded values land within 0.0011 of the .LS text (the .LS prints 3 decimals).

Worked example — **P[2]**, record at 0x1EBB:

```
1EBB  00 24                     len = 36
1EBD  00 02                     P[2]
1EBF  01                        GP1
1EC0  00 20 12 00               cartesian descriptor
1EC4  11                        UF = 1, UT = 1
1EC5  C3 49 DB 5C   X = -201.85687  mm      .LS -201.857
1EC9  C4 48 D6 CA   Y = -803.35608  mm      .LS -803.356
1ECD  43 2D 86 B8   Z =  173.52625  mm      .LS  173.526
1ED1  C3 32 9D E6   W = -178.61679 deg      .LS -178.617
1ED5  3C D5 60 D5   P =    0.026047 deg     .LS     .026
1ED9  BF 8D 96 0C   R =   -1.10614 deg      .LS   -1.106
1EDD  00 00 FF 31   CONFIG turns 0, 0, -1   .LS 'N U T, 0, 0, -1'
```

Worked example — **P[1]**, record at 0x1E99 (joint, no CONFIG field at all):

```
1E99  00 20                     len = 32
1E9B  00 01                     P[1]
1E9D  01                        GP1
1E9E  00 1C 19 30               joint descriptor
1EA2  11                        UF = 1, UT = 1
1EA3  BF E6 C3 1B   J1 = -1.8028291 rad = -103.2945 deg   .LS -103.295
1EA7  BE 27 51 1A   J2 = -0.1633953 rad =   -9.3619 deg   .LS   -9.362
1EAB  BE F8 B5 8C   J3 = -0.4857601 rad =  -27.8320 deg   .LS  -27.832
1EAF  3B CA C8 23   J4 =  0.0061884 rad =    0.3546 deg   .LS     .354
1EB3  BF 8D E4 55   J5 = -1.1085306 rad =  -63.5141 deg   .LS  -63.514
1EB7  C0 90 14 A2   J6 = -4.5025187 rad = -257.9753 deg   .LS -257.975
```

(Independent confirmation of the 0x00 ring prefill: P[6] J4 is `00 00 00 00` = exactly 0.0,
matching `J4 = .000` in the .LS.  Under the 0x20 prefill it decoded as `00 20 00 00`, a
denormal 1.68e-37.)

### 2.3 CONFIG — the 4 bytes at +32 (cartesian only)  [C for 3 of 4 bytes]

```
cfg[0] = int8  turn number 1     (J1)
cfg[1] = int8  turn number 2     (J4)
cfg[2] = int8  turn number 3     (J6)
cfg[3] = u8    posture flags     0x31 on 32 of 33 records, 0x30 on P[25]     [?]
```

**`(cfg[0], cfg[1], cfg[2])` equals the three CONFIG turn numbers printed in PG21.LS for all
33 cartesian records** — verified programmatically, zero mismatches.  In PG21 the turns are
always `0, 0, 0` or `0, 0, -1`, so only the three observed words occur:

```
00 00 00 31  x21   turns 0,0,0     'N U T, 0, 0, 0'
00 00 FF 31  x11   turns 0,0,-1    'N U T, 0, 0, -1'
00 00 FF 30  x1    turns 0,0,-1    'N U T, 0, 0, -1'   <- P[25] only
```

`cfg[3]`: the `N U T` (non-flip / up / toward) flags are identical in every PG21 record, so they
carry no signal and cannot be located inside this byte.  `0x31 = 0b0011_0001`; P[25] differs only
in bit 0 while its printed CONFIG is identical to ten other records.  **I cannot explain bit 0,
and I cannot confirm which bits are flip/up/front.** For new points, copy `0x31` (the value used
by 32 of 33 records).

> Correction to an earlier note: under the stale 0x20-prefill decode `cfg[0]` appeared to be a
> meaningless `0x00`/`0x20` flip.  With the correct decode it is simply turn number 1, always 0.

### 2.4 Inventory actually found in the binary  [C]

```
40 records, strictly ascending by position number:
  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25
  27 28 30 33 34 35 36 37 38 39 42 43 47 49 56
JOINT (len 32, 7 records) : 1, 5, 6, 15, 30, 33, 34
CART  (len 36, 33 records): the other 33
```

This is **40 positions, not 44**, and matches `PG21.LS` exactly — P26, P29, P31, P32, P40, P41,
P44, P45, P46, P48 and P50..P55 are absent from both.  Missing numbers are simply skipped: there
is no placeholder record, no index table and no count field anywhere.  Ordering is ascending.

### 2.5 .LS → binary is LOSSY (matters for the project's acceptance gate)

`PG21.LS` prints 3 decimals.  Re-packing the printed text gives a **different float32 bit pattern
for all 240 values**.  Example: the file holds `C3 49 DB 5C` = −201.85687255859375, the .LS prints
`-201.857`, and `float32(-201.857)` = `C3 49 DB 5D`.  **A pure .LS → .TP encoder cannot reproduce
the original position bytes**; the only lossless path is to copy position records from the decoded
binary.

Side observation for anyone writing .LS files: FANUC's formatter rounds for |v| ≥ 1 (231/240
values match round-half-away-from-zero) but **truncates for |v| < 1** (0.025937 → `.025`,
0.570544 → `.570`, 0.635851 → `.635`).  All 9 deviations from round-to-nearest have |v| < 1.

---

## 3. Section C — /APPL  (0x246D .. 0x24C0)

```
0000246D  ff ff 04 00 04 00 01 03  00 01 01 00 04 00 00 04  |................|
0000247D  57 4e 48 44 00 03 00 01  01 00 00 03 00 00 06 53  |WNHD...........S|
0000248D  47 4c 59 41 56 00 02 00  00 08 53 50 4f 54 01 00  |GLYAV.....SPOT..|
0000249D  00 00 00 01 00 00 0c 4d  55 41 50 00 00 00 02 00  |.......MUAP.....|
000024AD  00 00 00 00 00 00 00 0a  4c 41 4e 47 50 47 31 34  |........LANGPG14|
000024BD  00 00 ff ff                                       |....|
```

### 3.1 Record framing  [C — parses the section with zero leftover bytes]

```
<u16BE block_idx> <u16BE sub_idx> <u8 len> <len bytes of body>
```

| off | block_idx | sub_idx | len | body |
|---|---|---|---|---|
| 0x2470 | 4 | 1 | 3  | `00 01 01` |
| 0x2478 | 4 | 0 | 4  | `"WNHD"` |
| 0x2481 | 3 | 1 | 1  | `00` |
| 0x2487 | 3 | 0 | 6  | `"SGLYAV"` |
| 0x2492 | 2 | 0 | 8  | `"SPOT"` + `01 00 00 00` |
| 0x249F | 1 | 0 | 12 | `"MUAP"` + `00 00 00 02 00 00 00 00` |
| 0x24B0 | 0 | 0 | 10 | `"LANG"` + `"PG14"` + `00 00` |

then `FF FF` at 0x24BF = EOF.

**[G]** `block_idx` counts **down** over the five named application blocks (4,3,2,1,0 = "blocks
still to come"), and `sub_idx` counts down over the records inside a block (WNHD and SGLYAV have
2 records each — a data record then the name record; SPOT/MUAP/LANG have 1 record that carries
name and data together).  Under the corrected 0x00 decode every header byte outside these two
fields is zero, which is what makes this framing credible.

### 3.2 Mapping onto the /APPL block of PG21.LS

```
/APPL
  SPOT : TRUE ;
AUTO_SINGULARITY_HEADER;
  ENABLE_SINGULARITY_AVOIDANCE   : FALSE;
  SPOT Welding Equipment Number : 1 ;
PLTZ_MODE_HEADER;
 PLTZ_MODE_ENABLE   : FALSE;
 J4TURN  : ZERORAD;
 ORIENT  : DOWNWARDS;
```

| tag | data | interpretation |
|---|---|---|
| `WNHD` | `00 01 01` (separate record) | **[G]** application header; the two `01`s ≙ `SPOT : TRUE` plus one more enabled flag |
| `SGLYAV` | `00` (separate record) | **[G, strong]** **S**in**G**u**L**arit**Y** **AV**oidance ⇒ `AUTO_SINGULARITY_HEADER` / `ENABLE_SINGULARITY_AVOIDANCE : FALSE` — the single data byte is 0 = FALSE |
| `SPOT` | `01 00 00 00` | **[G, strong]** `SPOT Welding Equipment Number : 1` — leading `01` = 1 |
| `MUAP` | `00 00 00 02 00 00 00 00` | **[G]** the `PLTZ_MODE_HEADER` block: `PLTZ_MODE_ENABLE : FALSE` (0), `J4TURN : ZERORAD` (0), `ORIENT : DOWNWARDS` (the `02` at data offset 3).  Which byte is which keyword is a guess; only the `02` is non-zero |
| `LANG` | `"PG14" 00 00` | **[C]** carries **FILE_NAME = PG14** (matches `FILE_NAME = PG14;` in /ATTR).  ASCII, two trailing NULs, no fixed width ⇒ record len = 4 + len(filename) + 2.  Why the tag reads "LANG" is **[?]** |

**Unexplained in section C:** the exact meaning of `00 01 01` (WNHD), the `00 00 00` tail of the
SPOT data, seven of the eight MUAP data bytes, and the `LANG` tag name.  All preserved verbatim.

---

## 4. Complete list of bytes I could NOT explain

| offset(s) | bytes | note |
|---|---|---|
| 0x0000..0x0003 | `00 00 03 00` | file preamble; `03` guessed to be a format/type tag |
| 0x0028..0x0029 | `00 00` | after the program name |
| 0x0037..0x0038 | `00 00` | after OWNER (or the high half of PROG_SIZE — see §1.2) |
| 0x0057..0x005A | `00 00 00 00` | unused/zero attribute slot |
| 0x0063..0x007A | 24 bytes | attribute area; only `0x68 = 50 = TASK_PRIORITY` identified; the three `01` at 0x64/0x72/0x77 unassigned |
| /POS +5, +6 | `12 00` (cart) / `19 30` (joint) | representation code, constant per kind |
| /POS cfg[3] | `31` (32×) / `30` (P[25] only) | posture-flag byte; bit 0 unexplained |
| /APPL 0x2470 body | `00 01 01` | WNHD data record |
| /APPL SPOT data +1..+3 | `00 00 00` | |
| /APPL MUAP data | `00 00 00 02 00 00 00 00` | only the `02` is non-zero |

Underdetermined rather than unexplained: how to **compute** PROG_SIZE and MEMORY_SIZE for a
program that does not already exist.

---

## 5. Acceptance gate — actual measured result

```
$ python3 meta_codec.py          # runs against PG21.tp.raw0
  HEADER   OK  126 bytes round-tripped byte-for-byte
  /POS     OK  1495 bytes round-tripped byte-for-byte
  /APPL    OK  84 bytes round-tripped byte-for-byte
  WHOLE    OK  9409 bytes round-tripped byte-for-byte
exit=0
```

`encode(decode(x)) == x` holds for all three sections.  Re-assembling
`encode_header ‖ raw0[0x007E:0x1E96] ‖ encode_pos ‖ encode_appl` reproduces the entire
9409-byte payload byte-for-byte.  **Zero mismatching offsets.**

Caveat outside this scope: `tplib.compress(tplib.decompress(PG21.TP))` produces 4251 bytes vs the
original 4233 — the LZSS *decompressor* is exact, the greedy *compressor* does not reproduce
FANUC's match choices.  That is a container-level issue.

---

## 6. What must change to emit PG21T5FX

Implemented in `meta_codec.build_target_sections()`; the hex below is what `demo_target()`
actually printed.

### 6.1 Section A — 126 bytes, unchanged in size

| field | offset | PG21 | PG21T5FX | new bytes |
|---|---|---|---|---|
| program name | 0x04 (36) | `PG21` + NULs | `PG21T5FX` + NULs | `50 47 32 31 54 35 46 58` + 28×`00` |
| COMMENT | 0x39 (18) | `PICK HEAVY DUTY` | `PG21T 5 BAY CMT` | `50 47 32 31 54 20 35 20 42 41 59 20 43 4D 54` + 3×`00` |
| LINE_COUNT | 0x5B | 550 | **599** | `00 00 02 57` |
| MODIFIED | 0x53 | 26-09-17 06:01:42 | 26-09-18 00:48:00 | `5D 32 06 00` |
| PROG_SIZE | 0x4B | 12956 | **unchanged** (PG21T5FX.LS also says 12956) | `00 00 32 9C` |
| MEMORY_SIZE | 0x5F | 13648 | **unchanged** (PG21T5FX.LS also says 13648) | `00 00 35 50` |

OWNER, CREATE and the 24 attribute bytes at 0x63 are copied verbatim.  Both strings are shorter
than their fields, so the /ATTR record length stays `00 4C` = 76.

```
00 00 03 00 50 47 32 31 54 35 46 58 00 00 00 00 00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ff ff 01 00 4c 4d
4e 45 44 49 54 4f 52 00 00 50 47 32 31 54 20 35 20 42 41 59 20 43 4d 54
00 00 00 00 00 32 9c 5b 18 a9 c4 5d 32 06 00 00 00 00 00 00 00 02 57 00
00 35 50 00 01 00 00 00 32 00 00 00 00 00 00 00 00 00 01 00 00 00 00 01
00 00 00 ff ff 02
```

### 6.2 Section B — 1495 → 1533 bytes (+38)

`PG21T5FX.LS` has PG21's 40 positions plus **P[57]**: cartesian, `CONFIG : 'N U T, 0, 0, -1'`,
and its six values are **identical to P[56]**.  So P[57] is emitted as a byte-copy of the P[56]
record with only the number changed to `00 39`, appended after P[56] (ascending order kept):

```
00 24 00 39 01 00 20 12 00 11 c4 22 2c 1d c3 fb 5a 71 43 2c c0 6a
c3 32 53 64 c0 0d 86 a2 c1 b5 8b 97 00 00 ff 31
```

This side-steps the precision loss of §2.5 completely.  **If a genuinely new point had to be
built from .LS text:** `struct.pack('>6f', X, Y, Z, W, P, R)` (mm / degrees), descriptor
`01 00 20 12 00 11`, and CONFIG = `int8(t1) int8(t2) int8(t3) 0x31` — but the float bits will not
match what a controller would have written, and `cfg[3] = 0x31` remains a guess.

### 6.3 Section C — 84 → 88 bytes (+4)

Only the `LANG` record changes: body `"LANG" + "PG14" + 00 00` (len 10) becomes
`"LANG" + "PG21T5FX" + 00 00` (len **14 = 0x0E**), giving `FILE_NAME = PG21T5FX`:

```
... 00 00 00 00 0e 4c 41 4e 47 50 47 32 31 54 35 46 58 00 00 ff ff
```

The "name + two NULs, no fixed width" rule is extrapolated from one sample **[G]**; if the
controller pads FILE_NAME to a fixed width, this record length is wrong.

### 6.4 Not handled here

The /MN body must grow from 550 to 599 records (other worker's scope), and the assembled payload
must be re-compressed.  Since `tplib.compress` does not reproduce FANUC's LZSS match choices, the
final .TP will differ in size from a controller-written file even if the decompressed payload is
correct; whether the controller accepts it is untested.
