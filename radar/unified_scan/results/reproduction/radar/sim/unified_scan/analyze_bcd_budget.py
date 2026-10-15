"""Exact integer exhaustive bound against ideal 0.17 mm/us at 50 MHz."""
import json
from pathlib import Path

worst = (0, 0, 0)
minimum = (0, 0)
maximum = (0, 0)
valid_widths = 0
# Includes every clock-resolved width up to 4002 ideal mm, beyond valid range.
for clocks in range(1, 1_177_060):
    measured = (clocks - 1) // 294
    error_numerator = 10_000 * measured - 34 * clocks
    if 20 <= measured <= 4000:
        valid_widths += 1
        if abs(error_numerator) > worst[0]:
            worst = (abs(error_numerator), clocks, measured)
        minimum = min(minimum, (error_numerator, clocks))
        maximum = max(maximum, (error_numerator, clocks))
assert worst[0] <= 20_000
result = {
    "formula": "reported_mm=floor((echo_clocks-1)/294); ideal_mm=34*echo_clocks/10000",
    "exhaustive_clock_widths": 1_177_059,
    "valid_clock_widths": valid_widths,
    "max_absolute_error_mm": worst[0] / 10_000,
    "worst_echo_clocks": worst[1],
    "worst_reported_mm": worst[2],
    "min_signed_error_mm": minimum[0] / 10_000,
    "max_signed_error_mm": maximum[0] / 10_000,
    "timeout": "31 global 1-ms ticks: 30..31 ms plus synchronizer/commit clocks",
    "validity": "range is checked on reported mm (20..4000 inclusive), no legacy-boundary equivalence",
}
out = Path(__file__).resolve().parents[2] / "unified_scan/results/bcd_budget"
out.mkdir(parents=True, exist_ok=True)
(out / "ideal_error.json").write_text(json.dumps(result, indent=2), encoding="utf8")
print(json.dumps(result, indent=2))
