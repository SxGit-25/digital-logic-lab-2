"""Generate independently rounded Q1.8/Q1.7/Q1.6 tables and UFM images."""
from pathlib import Path
import math

HERE = Path(__file__).resolve().parent
values = {f: [int(math.sin(math.radians(a)) * (1 << f) + 0.5)
              for a in range(91)] for f in (8, 7, 6)}
case = '\n'.join(
    f"            7'd{a}: sin_lookup = FRACTION_BITS == 8 ? 9'd{values[8][a]} : "
    f"FRACTION_BITS == 7 ? 8'd{values[7][a]} : 7'd{values[6][a]};"
    for a in range(91))
rtl = HERE.parent / 'rtl' / 'lcd_sin_lut.v'
source = rtl.read_text(encoding='utf-8')
begin, end = '// BEGIN GENERATED SIN TABLE', '// END GENERATED SIN TABLE'
prefix, tail = source.split(begin)
_, suffix = tail.split(end)
rtl.write_text(prefix + begin + '\n' + case + '\n        ' + end + suffix, encoding='utf-8')
for f, table in values.items():
    padding = (1 << (15 - f)) - 1
    mif = ['WIDTH=16;', 'DEPTH=512;', 'ADDRESS_RADIX=UNS;', 'DATA_RADIX=HEX;', 'CONTENT BEGIN']
    mif += [f'    {a}: {((v << (15-f)) | padding):04X};' for a, v in enumerate(table)]
    mif += ['    [91..511]: FFFF;', 'END;']
    (HERE / f'lcd_sin_q{f}.mif').write_text('\n'.join(mif) + '\n', encoding='ascii')
    (HERE / f'lcd_sin_q{f}.hex').write_text('\n'.join(f'{v:03x}' for v in table) + '\n', encoding='ascii')
