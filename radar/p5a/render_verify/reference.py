"""Integer-only independent LCD image reference (no production RTL imports)."""
from collections import defaultdict
from pathlib import Path
import argparse
import json

Q = 1 << 15

def vectors():
    c, s, phase = Q, 0, 63
    result = [(c, s)]
    for angle in range(1, 181):
        total = phase + 15
        for _ in range(2 + total // 64):
            c -= s >> 7
            s += c >> 7
        phase = total % 64
        result.append((c, s))
    return result

VECTORS = vectors()

def ray_masks(angle, first=6, last=48):
    """OR pixels before touching RAM; repeated coordinates flip at most once."""
    masks = defaultdict(int)
    c, s = VECTORS[angle]
    for radius in range(first, last + 1):
        x = 64 + (radius * c + Q // 2) // Q
        y = 63 - (radius * s + Q // 2) // Q
        assert 0 <= x < 128 and 8 <= y < 64, (angle, radius, x, y)
        # page1 status owns x<=32 and x>=100; rays never enter it.
        assert not (y < 16 and (x <= 32 or x >= 100))
        masks[(y // 8) * 132 + x] |= 1 << (y % 8)
    return dict(masks)

def load_background(path):
    packed = [int(x, 16) for x in Path(path).read_text().split()]
    assert len(packed) == 1024
    return bytearray(packed[p * 128 + x] if x < 128 else 0
                     for p in range(8) for x in range(132))

class Reference:
    def __init__(self, background, continuous=False, beam=False):
        self.background = bytearray(background)
        self.ram = bytearray(background)
        self.continuous = continuous
        self.beam_enabled = beam
        self.beam = None

    def toggle(self, angle, length):
        for address, mask in ray_masks(angle, last=length).items():
            self.ram[address] ^= mask

    def remove_beam(self):
        if self.beam is not None:
            self.toggle(*self.beam)
            self.beam = None

    def request(self, angle, up, radius, valid):
        self.remove_beam()
        if angle == 180 and not up:
            erase_angles = range(170, 181)
        elif angle == 0 and up:
            erase_angles = range(11)
        elif not self.continuous:
            erase_angles = [angle]
        elif up and angle <= 170:
            erase_angles = [angle + 10]
        elif not up and angle >= 10:
            erase_angles = [angle - 10]
        else:
            erase_angles = []
        for a in erase_angles:
            for address, mask in ray_masks(a).items():
                self.ram[address] = (self.ram[address] & ~mask) | (self.background[address] & mask)
        if valid and radius <= 48:
            for address, mask in ray_masks(angle, max(6, radius), max(6, radius)).items():
                self.ram[address] |= mask
        no_beam = bytes(self.ram)
        length = max(6, radius) - 2 if valid and radius <= 48 else 48
        if self.beam_enabled and length >= 6:
            self.toggle(angle, length)
            self.beam = (angle, length)
        return no_beam

def scenarios(roundtrips=3):
    out = []
    for cycle in range(roundtrips):
        for angle, up in [(a, True) for a in range(181)] + [(180, False)] + [(a, False) for a in range(179, 0, -1)] + [(0, True)]:
            radius = [0, 2, 5, 6, 7, 8, 16, 31, 48, 49, 63][(angle + cycle * 3) % 11]
            valid = (angle + cycle) % 7 != 0
            out.append(dict(angle=angle, up=up, radius=radius, valid=valid))
    # Direction/endpoint/distance changes and repeated same-angle refresh.
    out += [dict(angle=a, up=u, radius=r, valid=v) for a, u, r, v in
            [(90, True, 8, True), (90, True, 38, True), (90, False, 6, True),
             (180, False, 48, True), (0, True, 0, False)]]
    return out

def prepare(out, background, mode, beam=False, smoke=False):
    out = Path(out); out.mkdir(parents=True, exist_ok=True)
    bg = load_background(background)
    model = Reference(bg, continuous=(mode == 'continuous'), beam=beam)
    cases = scenarios()
    if smoke:
        cases = [dict(angle=a, up=u, radius=r, valid=v) for a,u,r,v in
                 [(0,True,8,True),(1,True,6,True),(45,True,16,True),(90,False,48,True),
                  (179,True,49,True),(180,False,31,True),(0,True,0,False)]]
    (out/'background_bytes.mem').write_text(Path(background).read_text())
    def hexfile(name, data):
        (out/name).write_text(''.join(f'{value:02x}\n' for value in data))
    hexfile('initial_expected.mem', bg)
    expected = bytearray(); unbeamed = bytearray()
    with (out/'requests.mem').open('w') as f:
        for row in cases:
            a = row['angle']; bcd = (a//100)*256 + ((a//10)%10)*16 + a%10
            word = (bcd << 8) | (int(row['up']) << 7) | (int(row['valid']) << 6) | row['radius']
            f.write(f'{word:05x}\n')
            unbeamed.extend(model.request(**dict(angle=a, up=row['up'], radius=row['radius'], valid=row['valid'])))
            expected.extend(model.ram)
    hexfile('expected.mem', expected)
    hexfile('unbeamed_expected.mem', unbeamed)
    extra = ('`define P5_BEAM_TEST\n`define P5_CORE_BEAM_PARAMETER ,.P5_BEAM(1)\n'
             '`define P5_CORE_BEAM_PORTS ,.stop_request(stop_request),.quiescent(quiescent)\n') if beam else (
             '`define P5_CORE_BEAM_PARAMETER\n`define P5_CORE_BEAM_PORTS\n')
    (out/'fixture.vh').write_text(f'`define REQUEST_COUNT {len(cases)}\n`define CONTINUOUS_MODE {int(mode=="continuous")}\n`define BEAM_ENABLE {int(beam)}\n'+extra)
    (out/'reference.json').write_text(json.dumps(dict(mode=mode, beam=beam, requests=cases,
        full_roundtrips=0 if smoke else 3, vector_algorithm='F15/K7; phase63 +15 mod64; 2+carry microsteps'),indent=2))
    return len(cases)

def compare(out):
    out=Path(out)
    cases=json.loads((out/'reference.json').read_text())['requests']
    expected=bytes(int(x,16) for x in (out/'expected.mem').read_text().split())
    actual=bytes(int(x,16) for x in (out/'actual.mem').read_text().split())
    assert len(actual)==len(expected)==len(cases)*1056, (len(actual),len(expected))
    for i,(a,b) in enumerate(zip(actual,expected)):
        if a!=b:
            frame,addr=divmod(i,1056);page,col=divmod(addr,132)
            raise AssertionError(f'frame={frame} case={cases[frame]} page={page} col={col}: actual={a:02x} expected={b:02x}')
    print(f'PASS Python byte comparison: {len(cases)} requests, {len(actual)} bytes')
    from PIL import Image
    frame=actual[-1056:]
    image=Image.new('RGB',(128,64),(205,220,180))
    for y in range(64):
        for x in range(128):
            if frame[(y//8)*132+x] & (1<<(y%8)): image.putpixel((x,y),(25,43,30))
    image.resize((1024,512),Image.Resampling.NEAREST).save(out/'final_preview.png')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','compare']);p.add_argument('out');p.add_argument('--background');p.add_argument('--mode',default='basic',choices=['basic','continuous']);p.add_argument('--beam',action='store_true');p.add_argument('--smoke',action='store_true');a=p.parse_args()
    if a.action=='prepare': print('Prepared',prepare(a.out,a.background,a.mode,a.beam,a.smoke),'requests')
    else: compare(a.out)
