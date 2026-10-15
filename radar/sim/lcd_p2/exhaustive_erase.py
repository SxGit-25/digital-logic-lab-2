"""Exhaustive Q8 behind-target erase check; no DUT implementation is imported."""
from collections import defaultdict
from pathlib import Path
import csv
import json
import sys
sys.dont_write_bytecode=True
from verify_p2 import point

def future_angles(k, up):
    result=[]
    for _ in range(10):
        if k==180: up=False
        elif k==0: up=True
        k+=1 if up else -1
        result.append(k)
    return set(result)

def erase_angles(k,up,batch=True):
    if batch and k==180 and not up:return range(170,181)
    if batch and k==0 and up:return range(0,11)
    a=k+(10 if up else -10)
    return (a,) if 0<=a<=180 else ()

def run(out):
    out.mkdir(parents=True,exist_ok=True)
    summaries=[];all_hits=[]
    points={(a,r):point(a,r) for a in range(181) for r in range(49)}
    for minimum in range(4,49):
        by_coordinate=defaultdict(list)
        for a in range(181):
            for raw in range(49):
                effective=max(minimum,raw)
                by_coordinate[points[a,effective]].append((a,raw,effective))
        hits=[];effective_hits=set()
        for k in range(181):
            for up in (False,True):
                future=future_angles(k,up)
                for ea in erase_angles(k,up):
                    for n in range(minimum,49):
                        if n in (16,32,48):continue
                        for a,raw,effective in by_coordinate[points[ea,n]]:
                            if ((up and a<k) or (not up and a>k)) and a not in future:
                                x,y=points[ea,n]
                                hits.append((minimum,k,int(up),ea,n,a,raw,effective,x,y))
                                effective_hits.add((k,int(up),ea,n,a,effective,x,y))
        all_hits.extend(hits)
        summary=dict(minimum_radius=minimum,events_raw_radius=len(hits),
                     events_effective_radius=len(effective_hits),
                     minimum_original_radius=min((h[6] for h in hits),default=None),
                     minimum_effective_radius=min((h[7] for h in hits),default=None),
                     examples=hits[:8])
        summaries.append(summary)
        if minimum>=6 and not hits:break
    fields=['minimum_radius','current_angle','direction_up','erase_angle','erase_step','target_angle','raw_radius','effective_radius','x','y']
    with (out/'exhaustive_erase_hits.csv').open('w',newline='') as f:
        writer=csv.writer(f);writer.writerow(fields);writer.writerows(all_hits)
    report=dict(definition=dict(current_angle='k=0..180',direction='up=1 increasing, up=0 decreasing',
        behind='up:a<k; down:a>k; a not among next 10 actual one-degree positions including endpoint reversal',
        target='a=0..180, original radius 0..48, effective=max(minimum,original)',
        erase='normal k+/-10; at (180,down) batch170..180, at (0,up) batch0..10; steps minimum..48 excluding16/32/48',
        raw_event_key=fields,effective_event_key=[f for f in fields if f not in ('raw_radius','minimum_radius')]),
        thresholds=summaries,first_zero_minimum=summaries[-1]['minimum_radius'] if not summaries[-1]['events_raw_radius'] else None)
    (out/'exhaustive_erase_report.json').write_text(json.dumps(report,indent=2)+'\n')
    assert report['first_zero_minimum']==6,report
    print(json.dumps(report,indent=2))

if __name__=='__main__':run(Path(sys.argv[1]))
