"""Report exact measured real-delay cycles, or a conservative abstract bound."""
from pathlib import Path
import argparse,csv,json,re

p=argparse.ArgumentParser();p.add_argument('run',type=Path);p.add_argument('--mode',choices=['basic','continuous'],action='append');a=p.parse_args()
result={}
for mode in (a.mode or ['basic','continuous']):
    d=a.run/mode
    log=(d/'simulation.log').read_text(errors='replace')
    real='real_timing=1' in log
    rows=list(csv.DictReader((d/'timing.csv').open()))
    for row in rows:
        for key in row:
            if key!='angle_bcd':row[key]=int(row[key])
        total=sum(row[x] for x in ('ufm_cycles','lcd_read_cycles','lcd_write_cycles','overhead_cycles'))
        assert total==row['total_cycles'],(mode,row,total)
        if real:
            row['bound_cycles']=row['total_cycles']
        else:
            # Transaction-level model takes 2 cycles including acceptance;
            # physical phase controller takes 41(read)/17(write). Additional
            # request phasing can add at most 15 clocks per fixed-phase UFM.
            assert row['lcd_read_cycles']%2==row['lcd_write_cycles']%2==0
            row['bound_cycles']=row['total_cycles']+39*(row['lcd_read_cycles']//2)+15*(row['lcd_write_cycles']//2)+15*row.get('ufm_fetches',row['lcd_read_cycles']//4)
    worst=max(rows,key=lambda x:x['bound_cycles'])
    result[mode]=dict(real_timing=real,requests=len(rows),worst=worst,
        bound_ms=worst['bound_cycles']/50000,margin_to_60ms=60-worst['bound_cycles']/50000)
    init=re.search(r'INIT_PASS cycles=(\d+) writes=(\d+) ufm=(\d+) lcd_read=(\d+) lcd_write=(\d+) overhead=(\d+)',log)
    if init:
        result[mode]['initialization']=dict(zip(['cycles_including_5_reset','writes','ufm_cycles','lcd_read_cycles','lcd_write_cycles','overhead_cycles'],map(int,init.groups())))
    copy=re.search(r'INIT_COPY first_ufm_cycle=(\d+) through_display_on_cycles=(\d+) production_tick=(\d+)',log)
    if copy:
        result[mode]['initialization'].update(dict(zip(['first_ufm_cycle','copy_cycles','production_tick'],map(int,copy.groups()))))
(a.run/'timing_summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
