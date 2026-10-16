"""Exact 128x64 radar background, UFM formats and reversible PNG validation.

No external packages. Black pixels mean LCD bit 1. HEX is Altera's word
addressed Intel HEX format (16-bit data); .mem is $readmemh, never .hex.
"""
import argparse
import binascii
import json
import math
from pathlib import Path
import re
import struct
import zlib

HERE = Path(__file__).resolve().parent
FONT3 = {
    '0': ['111','101','101','101','111'],
    '.': ['000','000','000','000','010'],
    '4': ['101','101','111','001','001'],
    '8': ['111','101','111','101','111'],
    '1': ['010','110','010','010','111'],
    '2': ['111','001','111','100','111'],
}
FONT5 = {
    'D': [0x7F,0x41,0x41,0x22,0x1C],
    'E': [0x7F,0x49,0x49,0x49,0x41],
    'G': [0x3E,0x41,0x49,0x49,0x7A],
    'm': [0x7C,0x04,0x18,0x04,0x78],
    'L': [0x7F,0x40,0x40,0x40,0x40],
    'V': [0x1F,0x20,0x40,0x20,0x1F],
}

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', binascii.crc32(kind+data)&0xFFFFFFFF)

def write_png(path, pixels, scale=1):
    height, width = len(pixels), len(pixels[0])
    rows = b''.join((b'\x00'+bytes(0 if p else 255 for p in row for _ in range(scale)))*scale for row in pixels)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width*scale,height*scale,8,0,0,0,0))+chunk(b'IDAT',zlib.compress(rows,9))+chunk(b'IEND',b''))

def read_png(path):
    """Read non-interlaced grayscale/RGB/indexed/alpha PNG, depths 1/2/4/8.

    Refuse antialiasing rather than silently threshold the user's input.
    """
    raw = path.read_bytes()
    assert raw[:8] == b'\x89PNG\r\n\x1a\n', 'not PNG'
    offset, compressed, palette = 8, b'', None
    while offset < len(raw):
        size = struct.unpack('>I',raw[offset:offset+4])[0]
        kind, data = raw[offset+4:offset+8], raw[offset+8:offset+8+size]
        assert binascii.crc32(kind+data)&0xFFFFFFFF == struct.unpack('>I',raw[offset+8+size:offset+12+size])[0], 'PNG CRC'
        if kind == b'IHDR':
            w,h,depth,color,comp,filt,interlace = struct.unpack('>IIBBBBB',data)
            assert (w,h)==(128,64), 'PNG must be 128x64'
            assert depth in (1,2,4,8) and color in (0,2,3,4,6) and interlace==0
            assert depth==8 or color in (0,3), 'packed RGB unsupported'
        elif kind == b'PLTE':
            palette = [tuple(data[i:i+3]) for i in range(0,len(data),3)]
        elif kind == b'IDAT': compressed += data
        offset += size+12
    channels = {0:1,2:3,3:1,4:2,6:4}[color]
    bpp, stride = max(1,(channels*depth+7)//8), (w*channels*depth+7)//8
    packed, previous, image = zlib.decompress(compressed), bytearray(stride), []
    for y in range(h):
        mode = packed[y*(stride+1)]
        row = bytearray(packed[y*(stride+1)+1:(y+1)*(stride+1)])
        for i in range(stride):
            a,b,c = row[i-bpp] if i>=bpp else 0,previous[i],previous[i-bpp] if i>=bpp else 0
            if mode==1: pred=a
            elif mode==2: pred=b
            elif mode==3: pred=(a+b)//2
            elif mode==4:
                p=a+b-c
                pred=min(((abs(p-a),0,a),(abs(p-b),1,b),(abs(p-c),2,c)))[2]
            else:
                assert mode==0
                pred=0
            row[i]=(row[i]+pred)&255
        line=[]
        for x in range(w):
            if depth<8:
                sample=(row[x*depth//8]>>(8-depth-(x*depth)%8))&((1<<depth)-1)
                rgb=palette[sample] if color==3 else (sample*255//((1<<depth)-1),)*3
            else:
                samples=row[x*channels:(x+1)*channels]
                if color==3: rgb=palette[samples[0]]
                elif color in (0,4): rgb=(samples[0],)*3
                else: rgb=tuple(samples[:3])
                if color in (4,6): assert samples[-1]==255,'transparent PNG unsupported'
            assert rgb in ((0,0,0),(255,255,255)), f'non-binary pixel at {x},{y}: {rgb}'
            line.append(int(rgb==(0,0,0)))
        image.append(line)
        previous=row
    return image

def make_background(include_digits_header=False, include_level_header=False):
    pixels=[[0]*128 for _ in range(64)]
    static=set()
    def dot(x,y):
        assert 0<=x<128 and 0<=y<64,(x,y)
        pixels[y][x]=1
    # Midpoint circles: complete one-pixel semicircles, with exact cardinal points.
    for radius in (16,32,48,52):
        x,y,err=radius,0,1-radius
        while x>=y:
            for dx,dy in {(x,y),(y,x),(-x,y),(-y,x),(x,-y),(y,-x),(-x,-y),(-y,-x)}:
                if dy<=0: dot(64+dx,63+dy)
            y+=1
            if err<0: err+=2*y+1
            else:
                x-=1
                err+=2*(y-x)+1
    for angle in range(0,181,10):
        for radius in range(53,56 if angle%30==0 else 55):
            a=math.radians(angle)
            dot(math.floor(64+radius*math.cos(a)+0.5),math.floor(63-radius*math.sin(a)+0.5))
    for text,y0 in [('0.4',49),('0.8',33),('1.2',17)]:
        for i,ch in enumerate(text):
            for y,row in enumerate(FONT3[ch]):
                for x,value in enumerate(row):
                    if value=='1': dot(59+i*4+x,y0+y)
    for x in range(9,120): dot(x,63)
    for y in range(61,64):
        for x in range(62,67):
            if (x-64)**2+(y-63)**2<=4: dot(x,y)
    def text5(text,x0,y0):
        for i,ch in enumerate(text):
            for x,column in enumerate(FONT5[ch]):
                for y in range(7):
                    if (column>>y)&1:
                        dot(x0+i*6+x,y0+y)
                        static.add((x0+i*6+x,y0+y))
    if include_digits_header:
        text5('DEG',0,0)
        text5('mm',115,0)
    if include_level_header: text5('LV',0,8)
    return pixels,static

def check_ownership(pixels, static):
    conflicts=[]
    for y,row in enumerate(pixels):
        for x,pixel in enumerate(row):
            if not pixel: continue
            if y<8 and (x,y) not in static: conflicts.append([x,y,'page0 outside static text'])
            if 8<=y<=15 and (x<=32 or x>=100) and (x,y) not in static:
                conflicts.append([x,y,'page1 status must be zero'])
    assert not conflicts, 'ownership conflicts: '+json.dumps(conflicts)
    # r<=48 yields y>=15; for y=15..15 it is around x64 only.
    ray_conflicts=[]
    for angle in range(181):
        a=math.radians(angle)
        for radius in range(6,49):
            x=math.floor(64+radius*math.cos(a)+0.5)
            y=math.floor(63-radius*math.sin(a)+0.5)
            if y<8 or (8<=y<=15 and (x<=32 or x>=100)):
                ray_conflicts.append([angle,radius,x,y])
    assert not ray_conflicts, 'ray/status conflict'
    return {'background_conflicts':conflicts,'ray_conflicts':ray_conflicts,'ray_positions_checked':181*43}

def encode(pixels):
    data=[]
    for page in range(8):
        for x in range(128):
            data.append(sum(pixels[page*8+bit][x]<<bit for bit in range(8)))
    return [(data[i]<<8)|data[i+1] for i in range(0,1024,2)]

def decode(words):
    assert len(words)==512
    return [[((words[(y//8)*64+x//2]>>(8 if x%2==0 else 0))>>(y%8))&1 for x in range(128)] for y in range(64)]

def intel_record(address, kind, data):
    record=bytes([len(data),address>>8,address&255,kind])+data
    return ':'+(record+bytes([-sum(record)&255])).hex().upper()

def write_formats(folder, words):
    (folder/'background.mif').write_text('WIDTH=16;\nDEPTH=512;\nADDRESS_RADIX=HEX;\nDATA_RADIX=HEX;\nCONTENT BEGIN\n'+''.join(f'{i:03X} : {w:04X};\n' for i,w in enumerate(words))+'END;\n',encoding='ascii')
    # Altera HEX uses word addresses, while record length is a byte count.
    lines=[intel_record(i,0,b''.join(w.to_bytes(2,'big') for w in words[i:i+8])) for i in range(0,512,8)]
    (folder/'background.hex').write_text('\n'.join(lines+[':00000001FF'])+'\n',encoding='ascii')
    (folder/'background.mem').write_text(''.join(f'{w:04X}\n' for w in words),encoding='ascii')
    (folder/'background_bytes.mem').write_text(''.join(f'{(w>>shift)&255:02X}\n' for w in words for shift in (8,0)),encoding='ascii')

def read_mif(path):
    records=re.findall(r'^([0-9A-F]+)\s*:\s*([0-9A-F]+);',path.read_text(),re.M)
    words=[None]*512
    for a,w in records: words[int(a,16)]=int(w,16)
    assert all(w is not None for w in words)
    return words

def read_hex(path):
    words=[None]*512
    for line in path.read_text().splitlines():
        b=bytes.fromhex(line[1:])
        assert line.startswith(':') and sum(b)%256==0 and len(b)==b[0]+5
        if b[3]==1: break
        assert b[3]==0 and b[0]%2==0
        address=int.from_bytes(b[1:3],'big')
        for i in range(b[0]//2): words[address+i]=int.from_bytes(b[4+i*2:6+i*2],'big')
    assert all(w is not None for w in words)
    return words

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=HERE/'base')
    parser.add_argument('--input',type=Path,help='encode an existing exact binary 128x64 PNG')
    parser.add_argument('--include-digits-header',action='store_true')
    parser.add_argument('--include-level-header',action='store_true')
    args=parser.parse_args()
    generated,static=make_background(args.include_digits_header,args.include_level_header)
    pixels=read_png(args.input) if args.input else generated
    ownership=check_ownership(pixels,static)
    args.output.mkdir(parents=True,exist_ok=True)
    write_png(args.output/'background.png',pixels)
    # Encode from the saved PNG, not from the generator's in-memory bitmap.
    source=read_png(args.output/'background.png')
    words=encode(source)
    write_formats(args.output,words)
    verified={}
    for name,reader in [('mif',read_mif),('hex',read_hex)]:
        restored=decode(reader(args.output/f'background.{name}'))
        mismatch=sum(a!=b for row_a,row_b in zip(source,restored) for a,b in zip(row_a,row_b))
        assert mismatch==0,(name,mismatch)
        write_png(args.output/f'decoded_{name}.png',restored)
        verified[name+'_pixel_mismatches']=mismatch
    write_png(args.output/'preview_8x.png',source,8)
    report={'width':128,'height':64,'words':512,'include_digits_header':args.include_digits_header,'include_level_header':args.include_level_header,'mapping':'word=page*64+col//2; even column high byte; bit0=top row','lit_pixels':sum(map(sum,source)),**ownership,**verified}
    (args.output/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__': main()
