"""Read-only scan-contract timing comparison; writes only adjacent evidence.

This is an ideal-event timing model, not a cycle-accurate RTL simulation.
Shared-edge nonblocking writes become visible to servo on a later clock edge.
Sub-millisecond tick phase/registered handshakes are intentionally omitted.
"""
from pathlib import Path
import csv
import hashlib
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[3]
BASE = "f4507a821c26b647131a962522dd61b9be2676c3"
files = ["servo_pwm", "radar_ctrl", "display_compose", "alarm_ctrl"]
evidence = [f"baseline_commit={BASE}"]
tokens = ("19999", "active_angle", "angle_idx", "SETTLE_MS", "PH_WAIT_APPLIED",
          "PH_SETTLE", "STANDBY_MS", "SLOT_MS", "current_valid", "CONTINUOUS_SAMPLE_MS",
          "continuous_angle", "direction_up", "2495", "505", "hist_valid")
for name in files:
    source = subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"{BASE}:radar/rtl/{name}.v"])
    evidence.append(f"\nradar/rtl/{name}.v sha256={hashlib.sha256(source).hexdigest()}")
    for number, line in enumerate(source.decode().splitlines(), 1):
        if any(token in line for token in tokens):
            evidence.append(f"{number}: {line}")
(OUT / "baseline_evidence.txt").write_text("\n".join(evidence)+"\n", encoding="utf-8")

rows = []
for first_boundary in (0, 5000, 10000, 15000, 19999):
    # A command written exactly at a boundary misses that latch edge.
    def applied_after(command_time):
        t = first_boundary
        while t <= command_time:
            t += 20000
        return t
    old_apply = applied_after(0)
    new_apply = applied_after(45000)
    rows.append(dict(first_boundary_us=first_boundary, old_final_apply_us=old_apply,
        logical_fastwalk_done_us=45000, new_final_apply_us=new_apply,
        old_sample_ideal_us=old_apply+300000,
        new_sample_with_full_settle_ideal_us=new_apply+300000,
        sample_delay_us=new_apply-old_apply,
        new_settle_if_old_sample_retained_us=old_apply+300000-new_apply,
        old_seg_target_change_us=0, new_seg_logical_stop_us=45000,
        new_seg_applied_stop_us=new_apply))
with (OUT / "phase_timing.csv").open("w", newline="", encoding="utf-8") as stream:
    writer = csv.DictWriter(stream, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)
assert {row["sample_delay_us"] for row in rows} == {40000,60000}
assert min(row["new_settle_if_old_sample_retained_us"] for row in rows) == 240000
print("PASS scan contract ideal-event audit: 5 PWM phases; full-settle sampling shifts 40/60ms; old sample retains only 240/260ms settle")
print("No production RTL or regression expectation modified.")
