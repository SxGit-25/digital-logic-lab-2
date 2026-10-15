"""Independent floating-point geometry check and deterministic LCD scoreboard inputs.

Run `python verify_p2.py prepare OUT`, simulations with cwd OUT, then
`python verify_p2.py analyze OUT`. Pillow is optional (PBM always produced).
"""
import csv
import json
import math
from collections import Counter
from pathlib import Path
import sys
import struct
import zlib

def png(bits, path, scale=6):
    """Lossless nearest-neighbor PNG using only Python's standard library."""
    width,height=128*scale,64*scale
    raw=b''.join(b'\0'+bytes(0 if bits[y//scale*128+x//scale] else 255 for x in range(width)) for y in range(height))
    def chunk(kind,data):
        return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data)&0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',width,height,8,0,0,0,0))+chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def components(points):
    unseen=set(points);sizes=[]
    while unseen:
        work=[unseen.pop()];size=0
        while work:
            x,y=work.pop();size+=1
            for dx in (-1,0,1):
                for dy in (-1,0,1):
                    if (x+dx,y+dy) in unseen:
                        unseen.remove((x+dx,y+dy));work.append((x+dx,y+dy))
        sizes.append(size)
    return sorted(sizes,reverse=True)

def point(angle, radius):
    theta = min(angle, 180-angle)
    sn = int(math.sin(math.radians(theta))*256+0.5)
    cs = int(math.cos(math.radians(theta))*256+0.5)
    dx, dy = (radius*cs+128)//256, (radius*sn+128)//256
    return 64 + (-dx if angle>90 else dx), 63-dy

def pixels(angle, up, radius, valid):
    ahead = angle + (10 if up else -10)
    if 0 <= ahead <= 180:
        for r in range(4, 49):
            if r not in (16,32,48):
                yield (*point(ahead,r), True, ahead,r)
    for r in range(4,49):
        if r in (16,32,48) or (valid and 4<=radius<=48 and r==radius):
            yield (*point(angle,r), False,angle,r)

def prepare(out):
    out.mkdir(parents=True,exist_ok=True)
    cases=[]
    # A complete sweep, reversing at 180 and returning to zero.
    for a in range(181): cases.append((a,a<180,12+(a//12)%27,1))
    for a in range(179,-1,-1): cases.append((a,a==0,12+(a//12)%27,1))
    # Endpoint reversals, invalid targets, and near-origin radius boundary.
    for r in (0,1,3,4,48,49,63):
        cases.append((90,1,r,1));cases.append((90,0,r,0))
    # Clear and rebuild a scene with three target groups, then reverse.
    for a in range(181): cases.append((a,a<180,20 if a<60 else 35 if a<120 else 44,1))
    for a in range(179,139,-1): cases.append((a,0,27,1))
    commands=[];records=[];ram=[0]*1056;aliases=[];targets={};ring_aliases=[]
    ring_pixels={point(a,r) for a in range(181) for r in (16,32,48)}
    snapshots={180:'outbound',360:'full_scan',len(cases)-1:'multiple_targets_turnaround'}
    for idx,(a,up,r,v) in enumerate(cases):
        ops=list(pixels(a,up,r,v));records.append((a<<16)|(up<<15)|(r<<9)|(v<<8)|len(ops))
        for x,y,erase,source,step in ops:
            page,mask=y//8,1<<(y%8);pos=page*132+x
            commands.append((int(erase)<<18)|(page<<15)|(x<<8)|mask)
            if erase:
                if (x,y) in ring_pixels and ram[pos]&mask:
                    ring_aliases.append(dict(update=idx,angle=a,erase_angle=source,erase_step=step,x=x,y=y))
                if (x,y) in targets and ram[pos]&mask:
                    aliases.append(dict(update=idx,angle=a,erase_angle=source,erase_step=step,
                                        target_angle=targets[x,y],x=x,y=y))
                ram[pos]&=255^mask
                targets.pop((x,y),None)
            else:
                ram[pos]|=mask
                if v and step==r and r not in (16,32,48): targets[x,y]=a
        if idx in snapshots:
            (out/(snapshots[idx]+'_expected.hex')).write_text('\n'.join(f'{n:02x}' for n in ram)+'\n')
    (out/'scenario.hex').write_text('\n'.join(f'{n:06x}' for n in records)+'\n')
    (out/'pixels.hex').write_text('\n'.join(f'{n:05x}' for n in commands)+'\n')
    collateral=[e for e in aliases if e['target_angle']!=e['erase_angle']]
    metadata=dict(scenarios=len(records),pixels=len(commands),snapshots=snapshots,
                  erased_existing_targets=len(aliases),natural_alias_erase_count=len(collateral),
                  natural_alias_erase_examples=collateral[:20],
                  ring_alias_erase_count=len(ring_aliases),ring_alias_erase_examples=ring_aliases[:20])
    (out/'scenario.json').write_text(json.dumps(metadata,indent=2)+'\n')
    (out/'scenario_counts.vh').write_text(f'`define SCENARIOS {len(records)}\n`define PIXELS {len(commands)}\n')
    small_ram=[0]*1056
    for name,args in [('alias_before',(172,1,26,1)),('alias_after',(180,0,0,0))]:
        for x,y,erase,_,_ in pixels(*args):
            pos=y//8*132+x;mask=1<<(y%8)
            small_ram[pos]=(small_ram[pos] & (255^mask)) if erase else (small_ram[pos]|mask)
        (out/(name+'_expected.hex')).write_text('\n'.join(f'{v:02x}' for v in small_ram)+'\n')
    print(json.dumps(metadata,indent=2))

def analyze(out):
    coords={};dist=Counter();axis=Counter();max_float=0.0
    with (out/'ray_coordinates.csv').open() as f:
        for row in csv.DictReader(f):
            v,a,r,x,y=(int(row[k]) for k in ('variant','angle','step','x','y'))
            key=(v,a,r)
            assert key not in coords,key
            coords[key]=(x,y)
            if v==0:
                fx=64+r*math.cos(math.radians(a));fy=63-r*math.sin(math.radians(a))
                # Half-up magnitude rounding, symmetric around x=64.
                dx=int(abs(r*math.cos(math.radians(a)))+0.5)
                ref=(64+(-dx if a>90 else dx),63-int(r*math.sin(math.radians(a))+0.5))
                ex,ey=abs(x-ref[0]),abs(y-ref[1]);dist[max(ex,ey)]+=1;axis[ex,ey]+=1
                max_float=max(max_float,abs(x-fx),abs(y-fy))
                assert max(ex,ey)<=1,(a,r,(x,y),ref)
                assert (x,y)==point(a,r)
    assert len(coords)==181*49*3,len(coords)
    for a in range(181):
        for r in range(49):
            x,y=coords[0,a,r]
            assert coords[1,a,r]==(x,y),('UFM',a,r)
            assert coords[2,a,r]==(128-x,y),('mirror',a,r)
    result=dict(coordinates=len(coords),unique_unmirrored=181*49,valid_output_combinations=181*45,
                rounded_reference_chebyshev_error=dict(dist),
                per_axis_error={f'{x},{y}':n for (x,y),n in axis.items()},
                max_axis_error_against_unrounded_float=max_float,
                ufm_case_identical=True,mirror_identical=True)
    result['max_euclidean_error_against_unrounded_float']=max(
        math.hypot(x-(64+r*math.cos(math.radians(a))), y-(63-r*math.sin(math.radians(a))))
        for (variant,a,r),(x,y) in coords.items() if variant==0)
    assert result['max_euclidean_error_against_unrounded_float']<=1
    image_checks={}
    for pbm in out.glob('*.pbm'):
        tokens=pbm.read_text().split();assert tokens[:3]==['P1','128','64']
        bits=list(map(int,tokens[3:]));assert len(bits)==8192
        expected=[int(v,16) for v in pbm.with_name(pbm.stem+'_expected.hex').read_text().split()]
        reference=[(expected[(y//8)*132+x]>>(y%8))&1 for y in range(64) for x in range(128)]
        assert bits==reference,pbm.name
        assert not any(bits[:128*8]),'Header page modified'
        assert bits[63*128+64]==0,'Center modified'
        if pbm.stem.startswith('alias_'):
            png(bits,pbm.with_suffix('.png'))
            image_checks[pbm.stem]=dict(exact_reference_match=True,target_38_59=bits[59*128+38])
            continue
        coverage={}
        for radius in (16,32,48):
            ring={point(a,radius) for a in range(181)}
            lit={(x,y) for x,y in ring if bits[y*128+x]}
            coverage[str(radius)]=dict(total_pixels=len(ring),lit_pixels=len(lit),
                 missing_pixels=sorted(ring-lit),reference_components_8=components(ring),actual_components_8=components(lit))
        image_checks[pbm.stem]=dict(exact_reference_match=True,ring_coverage=coverage)
        png(bits,pbm.with_suffix('.png'))
    result['images']=image_checks
    (out/'geometry_report.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':
    mode,out=sys.argv[1],Path(sys.argv[2])
    {'prepare':prepare,'analyze':analyze}[mode](out)
