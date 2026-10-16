"""Compare unified FSM UI writes with an independent pixel-column model."""
import argparse
import re
from pathlib import Path

SEGMENTS = ("abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg")


def glyph(s):
    left = (6 if "f" in s else 0) | (48 if "e" in s else 0)
    middle = (1 if "a" in s else 0) | (8 if "g" in s else 0) | (64 if "d" in s else 0)
    right = (6 if "b" in s else 0) | (48 if "c" in s else 0)
    return [left, middle, middle, middle, right, 0]


parser = argparse.ArgumentParser()
parser.add_argument("log", type=Path)
parser.add_argument("flags", help="three binary digits: digits/mode/level")
args = parser.parse_args()
digits, mode, level = (int(a) for a in args.flags)
expected = []
for frame, (angle, distance, continuous, strength) in enumerate((("010", "1234", 1, 2), ("030", "9012", 1, 5), ("135", "0456", 0, 0)), 1):
    if digits:
        for start, word in ((20, angle), (90, distance)):
            columns = [v for char in word for v in glyph(SEGMENTS[int(char)])]
            expected += [(frame, 0, start + i, v) for i, v in enumerate(columns)]
    if mode:
        chars = ("acdfg", "adef", "abcefg", "ceg") if continuous else ("acdfg", "defg", "adefg", "abefg")
        columns = [255, 255] + [v ^ 255 for char in chars for v in glyph(char)] + [255, 255]
        expected += [(frame, 1, 100 + i, v) for i, v in enumerate(columns)]
    if level:
        columns = [0 if i % 4 == 3 else (126 if i // 4 < strength else 66) for i in range(20)]
        expected += [(frame, 1, 13 + i, v) for i, v in enumerate(columns)]
raw = args.log.read_bytes()
text = raw.decode("utf-16" if raw.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig")
actual = [(int(a), int(b), int(c), int(d, 16)) for a, b, c, d in re.findall(r"^UI (\d+) (\d+) (\d+) ([0-9a-fA-F]+)\r?$", text, re.M)]
assert "PASS UI core" in text, "RTL did not complete"
assert len(actual) == len(expected), (len(actual), len(expected))
for i, (got, want) in enumerate(zip(actual, expected)):
    assert got == want, (i, got, want)
print(f"PASS Python UI core stream flags={args.flags} columns={len(actual)}")
