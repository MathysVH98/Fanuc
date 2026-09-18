# Converting `PG21T5FX.LS` to `.TP`

## How much of the target is covered by the reference

`fixtures/PG21.TP` / `fixtures/PG21.LS` are the same program in both formats, so every
instruction form they contain has a known-good binary encoding. Measuring the target
against that corpus:

| | lines | risk |
|---|---|---|
| exact textual twin in the reference | 423 | none — encoding is directly attested |
| plain comments (`! text`) | 163 | none — opcode `0x1E` is fully decoded |
| parameter variations on attested forms | 12 | low — each form appears 10–21x in the reference |
| **no reference form at all** | **1** | **the only genuine unknown** |
| total | 599 | |

## The 12 parameter variations

These reuse a form the reference exercises repeatedly, with a different number or string:

| target line | instruction | reference examples of this form |
|---|---|---|
| 107 | `CALL CLP1_CLS` | 10 |
| 154 | `LBL[111:GOTO DROP2]` | 21 |
| 172 | `LBL[140:RHTrlyBay1-4]` | 21 |
| 185 | `LBL[141:RHPrtTrly-Bay1]` | 21 |
| 204 | `LBL[142:RHPrtTrly-Bay2]` | 21 |
| 223 | `LBL[143:RHPrtTrly-Bay3]` | 21 |
| 241 | `LBL[144:RHPrtTrly-Bay4]` | 21 |
| 258 | `LBL[121:DROP RH PART]` | 21 |
| 337 | `LBL[150:LargeTrlyBay1-5]` | 21 |
| 432 | `J P[57] 100% FINE` | 21 |
| 526 | `LBL[11:Abort DROP2]` | 21 |
| 589 | `LBL[222:Skip Rivet]` | 21 |

Because each form appears many times in the reference with *varying* operands, the
encoder for it can be validated by byte-exact round-trip against the reference. A
parameter substitution into a form that round-trips is low risk.

## The one genuine unknown

```
line 345:  WAIT DI[43]=ON OR DI[44]=ON OR DI[45]=ON OR DI[46]=ON OR DI[47]=ON
```

The reference contains only the **four**-term version of this
(`WAIT DI[43]=ON OR DI[44]=ON OR DI[45]=ON OR DI[46]=ON`, at `PG21.LS` line 277).
The five-term form has to be produced by extending the operand list, which means
inferring the repeat structure rather than copying an attested encoding.

This is the single line in the file that cannot be validated against the reference.
Step over it specifically when first running the program.

## Other deltas

- program name `PG21` -> `PG21T5FX`
- `COMMENT` `"PICK HEAVY DUTY"` -> `"PG21T 5 BAY CMT"`
- `FILE_NAME` `PG14` -> `PG21T5FX`
- `LINE_COUNT` 550 -> 599
- one extra position, `P[57]`

`/APPL`, the `TCD` block, `DEFAULT_GROUP`, `CONTROL_CODE`, `LOCAL_REGISTERS`, and the
set of `CONFIG` strings are identical between the two programs.

## Known defect in the source `.LS`

`P[57]` is a byte-for-byte copy of `P[20]`/`P[56]`, the abort/retreat points. The
Pick1 bay approach points progress along the trolley at X≈145:

| bay | point | X | Y | CONFIG |
|---|---|---|---|---|
| 1 | P[22] | 140.830 | −799.036 | `N U T, 0, 0, 0` |
| 2 | P[19] | 142.989 | −1060.636 | `N U T, 0, 0, 0` |
| 3 | P[28] | 150.961 | −1308.314 | `N U T, 0, 0, 0` |
| 4 | P[39] | 143.991 | −1587.192 | `N U T, 0, 0, 0` |
| 5 | P[57] | **−648.689** | **−502.707** | **`N U T, 0, 0, −1`** |

A taught Bay 5 point would fall near X≈145, Y≈−1866. P[57] instead sends the robot to
the opposite side of the cell on a different wrist configuration, via a `J ... FINE`
move, while `ZONE(4)` is held. The source file flags this itself
(`!RETEACH P57 FOR BAY5 BEFORE AUTO`) but the compiled program will still execute it.

The conversion reproduces `P[57]` faithfully rather than substituting a guessed
position. **Reteach it before running.**
