#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
BUILD="$ROOT/sim/build"
mkdir -p "$BUILD"

RTL="$ROOT/rtl/reset_ctrl.v $ROOT/rtl/timebase.v $ROOT/rtl/switch_filter.v \
$ROOT/rtl/servo_pwm.v $ROOT/rtl/ultrasonic.v $ROOT/rtl/radar_ctrl.v \
$ROOT/rtl/display_compose.v $ROOT/rtl/seg_scan.v $ROOT/rtl/matrix_scan.v \
$ROOT/rtl/alarm_ctrl.v $ROOT/rtl/radar_top.v"

for name in servo_pwm ultrasonic radar_ctrl radar_top; do
    iverilog -g2005-sv -Wall -s "tb_$name" -o "$BUILD/$name.vvp" \
        $RTL "$ROOT/sim/tb_$name.v"
    vvp "$BUILD/$name.vvp"
done
