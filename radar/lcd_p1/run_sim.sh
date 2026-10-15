#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
mkdir -p radar/sim/build
iverilog -g2005-sv -Wall -s tb_lcd_p1 -o radar/sim/build/lcd_p1.vvp \
 radar/rtl/lcd_*.v radar/sim/lcd/*.v
vvp radar/sim/build/lcd_p1.vvp
