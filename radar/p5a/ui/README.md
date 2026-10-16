# P5 UI column generator

`radar/rtl/p5_ui_columns.v` is purely combinational. It creates no LCD bus
or state machine. Call it from the unified drawing FSM, and refresh numeric
columns after each completed drawing request.

Inputs: `kind[1:0]` (0 angle, 1 distance, 2 inverse mode word, 3 level bar),
`char_index[1:0]` from left to right, `font_col[2:0]` 0..5,
`angle_bcd[11:0]`, `distance_bcd[15:0]`, `mode_continuous`, `level[2:0]`,
`level_offset[4:0]` 0..19. Output: `column_byte[7:0]`.

Angle indices 0..2 select hundreds/tens/units; index3 is blank.
Distance indices 0..3 select thousands/hundreds/tens/units.
BCD 10 is dash, 11..15 blank, matching the existing display decode.
There is no decimal point and no leading-zero suppression. font_col5
is spacing; font_col6/7 defensively return the same blank byte.
Mode pixels are full-byte inverted, including the inter-character spacing.

Page0: map angle to x20..37, distance to x90..113. Page1: map mode's
four characters to x102..125, and let the core write 0xff at x100..101
and x126..127 for the inverse frame's side margins. The mode words are
`5CAn` (continuous) and `5tEP` (basic), in active-high abcdefg:

| Symbol | Segments |
|---|---|
| 5 | acdfg |
| C | adef |
| A | abcefg |
| n | ceg |
| t | defg |
| E | adefg |
| P | abefg |

Level maps to x13..32 using level_offset=x-13. Each four-column cell is
three identical columns followed by a zero spacer. Filled cell=0x7e;
unfilled cell=0x42; cell number less than `level` is filled. Level 0..5
is defined. Higher values saturate visually because there are only five
cells. Offsets >=20 return zero.

## Verification

Run `powershell -ExecutionPolicy Bypass -File radar/p5a/ui/run.ps1`.
Python generates 1160 independent vectors using segment-name sets rather
than copying the Verilog numeric bit constants. Coverage includes all
16 BCD codes, every angle/distance position, columns0..7, both mode words,
and level0..5 at all offsets0..31. RTL comparison passed all 1160 vectors.
The host's portable Icarus needs execution outside the sandbox, as in
the existing simulation scripts. No standalone LE claim is made; fitted
whole-system resource use remains authoritative.

## Existing decoder sharing

`radar_display_shared.v` owns an internal `decode(digit)` function using
the same abcdefg coding. It changes `digit` according to its independent
eight-row display scan and captures `decode(digit)` into `seg` when
`blank_stage==1`. Thus its live decoder output generally corresponds to
a different digit from the LCD column. Exposing its current seg output
does not correctly share an LCD decoder.

True sharing would require routing an LCD digit into that decoder when
`blank_stage!=1`, exposing a combinational `shared_segments[6:0]`, and
stalling LCD column consumption while the display captures its own digit.
That adds input mux/handshake logic and crosses the current module boundary;
it is not a zero-cost wiring change. The current generator shares a single
local decode across its angle/distance modes and reuses its column conversion
for the mode letters. Prefer this low-intrusion implementation unless an
actual full-system fitter comparison proves time-sharing saves LE. No
existing display module was modified for this subtask.
