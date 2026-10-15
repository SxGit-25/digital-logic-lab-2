"""Independent trigonometric, serialization image, and exhaustive erase checks."""
import csv
import json
import math
from collections import defaultdict
from pathlib import Path
import sys


def point(f, a, r):
    theta = min(a, 180-a)
    scale = 1 << f
    sine = int(math.sin(math.radians(theta))*scale+0.5)
    cosine = int(math.sin(math.radians(90-theta))*scale+0.5)
    dx = (r*cosine + scale//2)//scale
    dy = (r*sine + scale//2)//scale
    return 64 + (-dx if a > 90 else dx), 63-dy


def first_zero(points):
    summaries=[]
    for minimum in range(6, 49):
        by_coordinate=defaultdict(list)
        for a in range(181):
            for raw in range(49):
                by_coordinate[points[a,max(minimum,raw)]].append((a,raw))
        hits=0
        example=None
        for k in range(181):
            for up in (False,True):
                future=set(); position=k; direction=up
                for _ in range(10):
                    if position==180:direction=False
                    elif position==0:direction=True
                    position+=1 if direction else -1
                    future.add(position)
                erase=(range(170,181) if k==180 and not up else
                       range(0,11) if k==0 and up else
                       (k+10,) if up and k<=170 else
                       (k-10,) if not up and k>=10 else ())
                for ea in erase:
                    for step in range(minimum,49):
                        if step in (16,32,48):continue
                        for a,raw in by_coordinate[points[ea,step]]:
                            if ((up and a<k) or (not up and a>k)) and a not in future:
                                hits+=1
                                if example is None:example=[k,int(up),ea,step,a,raw]
        summaries.append(dict(minimum_radius=minimum,behind_hits=hits,example=example))
        if hits==0:return minimum,summaries
    raise AssertionError('No zero-hit minimum')


def run(stage):
    repo=Path(__file__).resolve().parents[2]
    report=[]
    for f in (8,7,6):
        points={(a,r):point(f,a,r) for a in range(181) for r in range(49)}
        max_error=0
        max_euclidean=0.0
        max_euclidean_rounded=0.0
        for (a,r),(x,y) in points.items():
            ideal=(64+int(math.cos(math.radians(a))*r+0.5) if a<=90 else
                   64-int(-math.cos(math.radians(a))*r+0.5),
                   63-int(math.sin(math.radians(a))*r+0.5))
            max_error=max(max_error,abs(x-ideal[0]),abs(y-ideal[1]))
            max_euclidean_rounded=max(max_euclidean_rounded,math.hypot(x-ideal[0],y-ideal[1]))
            max_euclidean=max(max_euclidean,math.hypot(x-(64+math.cos(math.radians(a))*r),y-(63-math.sin(math.radians(a))*r)))
        assert max_error<=1,(f,max_error)
        coordinates=[]
        for u in (0,1):
            with (stage/f'coefficients_q{f}_u{u}.csv').open() as handle:
                rows=list(csv.DictReader(handle))
            assert len(rows)==181*49,(f,u,len(rows))
            actual=[(int(row['angle']),int(row['step']),int(row['x']),int(row['y'])) for row in rows]
            assert len({(a,r) for a,r,x,y in actual})==181*49
            assert all((x,y)==points[a,r] for a,r,x,y in actual),(f,u)
            coordinates.append(actual)
        assert coordinates[0]==coordinates[1]
        mif=(repo/f'lcd_p2/lcd_sin_q{f}.mif').read_text()
        for a in range(91):
            value=int(math.sin(math.radians(a))*(1<<f)+0.5)
            packed=(value<<(15-f))|((1<<(15-f))-1)
            assert f'    {a}: {packed:04X};' in mif
        minimum,thresholds=first_zero(points)
        report.append(dict(fraction_bits=f,maximum_pixel_error=max_error,
                           maximum_euclidean_error=max_euclidean,
                           maximum_euclidean_error_vs_rounded=max_euclidean_rounded,
                           mif_matches_independent_direct_sine=True,
                           observed_pixels_per_mode=181*49,first_zero_minimum=minimum,
                           exhaustive_thresholds=thresholds))
    (stage/'coefficients_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))

if __name__=='__main__':run(Path(sys.argv[1]))
