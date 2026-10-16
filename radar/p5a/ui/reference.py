"""Independent Python seven-segment reference and exhaustive column vectors."""
from pathlib import Path
import json

SEGMENTS = ("abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg",
            "acdefg", "abc", "abcdefg", "abcdfg", "g", "", "", "", "", "")


def column(segments, x):
    if x == 0:
        return (6 if "f" in segments else 0) | (48 if "e" in segments else 0)
    if x in (1, 2, 3):
        return ((1 if "a" in segments else 0) | (8 if "g" in segments else 0)
                | (64 if "d" in segments else 0))
    if x == 4:
        return (6 if "b" in segments else 0) | (48 if "c" in segments else 0)
    return 0


vectors = []


def add(kind, index, x, angle, distance, mode, level, offset, expected):
    value = 0
    for number, width in zip((kind, index, x, angle, distance, mode, level, offset, expected),
                             (2, 2, 3, 12, 16, 1, 3, 5, 8)):
        assert 0 <= number < 1 << width
        value = (value << width) | number
    vectors.append(f"{value:013x}\n")


for kind in (0, 1):
    width = 3 if kind == 0 else 4
    for index in range(width):
        for digit in range(16):
            # Distinct other positions detect reversed or wrongly selected digits.
            number = sum(((digit + i - index) % 10 if i != index else digit)
                         << (4 * (width - 1 - i)) for i in range(width))
            for x in range(8):
                add(kind, index, x, number if kind == 0 else 0x123,
                    number if kind == 1 else 0x4567, 0, 0, 0, column(SEGMENTS[digit], x))
for x in range(8):
    add(0, 3, x, 0x123, 0x4567, 0, 0, 0, 0)
for mode, chars in ((0, ("acdfg", "defg", "adefg", "abefg")),
                    (1, ("acdfg", "adef", "abcefg", "ceg"))):
    for index, segments in enumerate(chars):
        for x in range(8):
            add(2, index, x, 0, 0, mode, 0, 0, column(segments, x) ^ 255)
for level in range(6):
    for offset in range(32):
        expected = 0 if offset >= 20 or offset % 4 == 3 else (126 if offset // 4 < level else 66)
        add(3, 0, 0, 0, 0, 0, level, offset, expected)
target = Path(__file__).parent
(target / "vectors.mem").write_text("".join(vectors), encoding="ascii")
(target / "vectors_count.vh").write_text(f"`define VECTOR_COUNT {len(vectors)}\n", encoding="ascii")
(target / "reference_checks.json").write_text(json.dumps({"vectors": len(vectors),
    "numeric_codes": "0..15, every position and column 0..7",
    "modes": ["5tEP", "5CAn"], "levels": "0..5, offsets 0..31"}, indent=2), encoding="ascii")
print(f"Generated {len(vectors)} independent Python reference vectors")
