# P5 UFM reader

`radar/rtl/p5_ufm_reader.v` uses one `altufm_none` with a 9-bit address and
16-bit data. `request` is accepted only while `busy=0`; `done` is one 50 MHz
cycle. `sequential=0` serially loads `address` MSB-first. `sequential=1`
uses UFM's address increment operation (one ARCLK pulse, ARSHFT=0), so the
first request after reset must load an explicit address. `value[15:8]` is
the even LCD column and `value[7:0]` is the odd column. The consumer must
use the value only after done.

The divider runs continuously at /16, with fixed phase even when gated:
ARCLK/DRCLK period >=320 ns, high/low >=160 ns, maximum 3.125 MHz.
Serial data is sampled 300 ns after DRCLK rising edge. An additional
320 ns access slot separates the address operation and data-register load;
the last ARCLK rise to first DRCLK rise is 640 ns. DRSHFT setup/hold is
160 ns; ARDIN setup is at least 40 ns on the first address pulse and
160 ns thereafter. All interface control/data is internal; no busy,
rtpbusy or oscillator signal is waited upon.

Timing basis is the existing P2 audit of MAX II Device Handbook table 5-21:
minimum clock period 100 ns, ARDIN setup/hold 20 ns, DRSHFT setup 60 ns
and hold 20 ns, flash tACC maximum 65 ns. The original handbook URL
`https://cdrdv2-public.intel.com/655094/max2_mii5v1.pdf` returned HTTP 403
during this implementation; local Quartus source was independently inspected.
The old 180 ns stress delay is retained in the behavioral model; it is not
presented as the hardware tDCO maximum. The 300 ns sampling delay leaves
120 ns beyond this deliberately conservative injected delay.

## Simulation

Run `powershell -ExecutionPolicy Bypass -File radar/p5a/ufm/run.ps1`.
The script copies inputs into an ASCII temporary directory. Portable
Icarus needs platform sandbox escalation on this host (inside sandbox it
crashes without diagnostics). The test reads all 512 addresses in a
permuted order, all 512 sequential addresses, and address wraparound;
it checks 1025 returned words, serial address order, 16 data-clock pulses
per word, ARDIN/DRSHFT setup/hold, and clock periods/pulse widths.

The supplied Quartus 9.1 `eda/sim_lib/maxii_atoms.v` lines 1420 onward
explicitly initializes contents from 16 generated `mem*` parameters,
rather than parsing `init_file` in standalone RTL simulation. Accordingly,
the permitted behavioral model loads `background.mem`, generated from the
same image as the hardware MIF, and exposes just one serial output bit.
Hardware still instantiates ALTUFM_NONE and uses `INIT_FILE`.
Physical acceptance must check that DEG is not mirrored and adjacent LCD
columns are not interchanged. Programmer must program and verify UFM.

## Latency and constraints for integration

Ignoring the caller's pulse-generation overhead, random word reads take
417..432 main-clock periods (8.34..8.64 us). Incrementing reads take
289..304 periods (5.78..6.08 us), depending on initial phase alignment.
An upper bound for 512 reads is 432 + 511*304 = 155776 cycles,
3.11552 ms. Add LCD copy cycles and caller state-machine overhead for
the complete initialization time. No independent LE claim is made;
the complete fitter is authoritative.

On the synthesized `arclk` and `drclk` register Qs create /16 generated
clocks, source the 50 MHz main clock; check their netlist names and the
actual clock edge phases. The only justified UFM-read sampling exception
is DRCLK -> this reader's `value[*]`, setup 15 / hold 14, `-end`,
representing 300 ns between launch and sampling. DRSHFT changes at phase8,
so its destination-specific path to the UFM data register may use setup8 /
hold15 `-start` (160 ns setup, 160 ns hold), following the P2 convention.
Do not apply this relaxation to all fabric->UFM paths: first ARDIN and
ARSHFT setup is only 40 ns for a just-in-time request. Keep their default
timing checks or explicitly constrain their proven first-edge relationship.
No false path is required for this reader. Validate exceptions against
actual fitted endpoints and report_timing after integration.
