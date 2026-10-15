"""Compose the phase oracle with the shared scan's 250us/8-row timing.

Compare first observable history-color changes when commits differ by 20ms.
Enumerate phases and both sides of latch edges; blanking is included. This
checks RUN history updates, not equivalence of the old and new scan waveform.
"""
import json
from pathlib import Path


def rgb(c, p):
    r = c == 5 or c == 4 and p < 3 or c == 3 and p < 2 or c == 2 and p == 0
    g = c == 1 or c == 2 and p != 0 or c == 3 and p >= 2 or c == 4 and p == 3
    return bool(r), bool(g)


def first_change(commit_ns, row, old, new):
    # Columns latch one clock after blank/index advance. Row enables a clock later.
    for slot in range(256):
        if slot % 8 != row:
            continue
        latch_ns = slot * 250_000 + 20
        if latch_ns <= commit_ns:
            continue
        if rgb(old, slot // 8 % 4) != rgb(new, slot // 8 % 4):
            return latch_ns + 20
    raise AssertionError("missing observable color change")


def main():
    count = worst = 0
    example = None
    for row in range(8):
        for old in range(6):
            for new in range(6):
                if old == new:
                    continue
                for slot in range(32):
                    for edge_offset in (-1, 0, 1, 19, 20, 21, 249_999):
                        commit = 8_000_000 + slot * 250_000 + edge_offset
                        a = first_change(commit, row, old, new)
                        b = first_change(commit + 20_000_000, row, old, new)
                        difference = abs(b-a)
                        assert difference <= 28_000_000
                        if difference > worst:
                            worst = difference
                            example = [row, old, new, slot, edge_offset, a, b]
                        count += 1
    out = Path(__file__).resolve().parents[2] / "unified_scan/results/matrix_bound"
    out.mkdir(parents=True, exist_ok=True)
    report = dict(cases=count, maximum_difference_ns=worst,
                  allowed_difference_ns=28_000_000, worst_example=example,
                  scope="shared scanner RUN history update; 20ms commit displacement")
    (out / "exhaustive.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print("PASS", report)


if __name__ == "__main__":
    main()
