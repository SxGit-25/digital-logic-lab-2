from pathlib import Path
import argparse
from reference import Reference,load_background
p=argparse.ArgumentParser();p.add_argument('out',type=Path);p.add_argument('background',type=Path);a=p.parse_args()
m=Reference(load_background(a.background),continuous=True,beam=True)
data=bytearray()
for angle,radius in [(90,24),(91,31)]:
    m.request(angle,True,radius,True);data.extend(m.ram)
(a.out/'alarm_expected.mem').write_text(''.join(f'{v:02x}\n' for v in data))
