"""Generate the single quadrant Q1.8 table and UFM initialization image."""
from pathlib import Path
import math

HERE = Path(__file__).resolve().parent
values = [int(math.sin(math.radians(a)) * 256 + 0.5) for a in range(91)]
case = '\n'.join(f"            7'd{a}: sin_lookup = 9'd{v};" for a, v in enumerate(values))
rtl = HERE.parent / 'rtl' / 'lcd_sin_lut.v'
source = rtl.read_text(encoding='utf-8')
begin, end = '// BEGIN GENERATED SIN TABLE', '// END GENERATED SIN TABLE'
prefix, tail = source.split(begin)
_, suffix = tail.split(end)
rtl.write_text(prefix + begin + '\n' + case + '\n        ' + end + suffix, encoding='utf-8')
mif = ['WIDTH=16;', 'DEPTH=512;', 'ADDRESS_RADIX=UNS;', 'DATA_RADIX=HEX;', 'CONTENT BEGIN']
mif += [f'    {a}: {((v << 7) | 127):04X};' for a, v in enumerate(values)]
mif += ['    [91..511]: FFFF;', 'END;']
(HERE / 'lcd_sin_q8.mif').write_text('\n'.join(mif) + '\n', encoding='ascii')
(HERE / 'lcd_sin_q8.hex').write_text('\n'.join(f'{v:03x}' for v in values) + '\n', encoding='ascii')
