"""Summarize actual Fitter reports; failed placement never has valid timing."""
import csv
import json
import re
from pathlib import Path

HERE=Path(__file__).resolve().parent
OUT=HERE/'results'
summary=[];modules=[]
for path in sorted(OUT.rglob('*.fit.rpt')):
    text=path.read_text(errors='replace')
    if '; Fitter Resource Utilization by Entity' not in text:
        continue
    rows=[]
    for line in text.split('; Fitter Resource Utilization by Entity',1)[1].splitlines():
        c=[v.strip() for v in line.split(';')]
        if len(c)<14 or not c[1].startswith('|') or not re.match(r'\d',c[2]):continue
        number=lambda value:int(re.match(r'[\d,]+',value).group().replace(',',''))
        own=re.search(r'\((\d+)\)',c[2])
        rows.append(dict(build=path.parent.relative_to(OUT).as_posix(),module=c[1],
                         le_including_children=number(c[2]),le_self=int(own.group(1)) if own else number(c[2]),
                         registers_including_children=number(c[3]),ufm=number(c[4]),pins=number(c[5])))
    if not rows:continue
    assert sum(r['le_self'] for r in rows)==rows[0]['le_including_children'],path
    modules+=rows
    stem=path.name[:-len('.fit.rpt')]
    fit_summary=path.with_name(stem+'.fit.summary')
    status=fit_summary.read_text(errors='replace') if fit_summary.exists() else text
    legal='Fitter Status : Successful' in status
    sta=path.with_name(stem+'.sta.summary')
    slacks=dict((name,float(v)) for name,v in re.findall(r'Type\s*:\s*(.*?)\r?\nSlack\s*:\s*([\d.-]+)',sta.read_text())) if sta.exists() and legal else {}
    record=dict(build=rows[0]['build'],fitter_success=legal,
                fitter_le=rows[0]['le_including_children'],registers=rows[0]['registers_including_children'],
                io=rows[0]['pins'],ufm=rows[0]['ufm'],slack_ns=slacks,
                resource_demand_only=not legal)
    summary.append(record)
with (OUT/'module_resources.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(modules[0]));w.writeheader();w.writerows(modules)
(OUT/'resource_comparison.json').write_text(json.dumps(summary,indent=2)+'\n')
for row in summary:
    if row['build'].startswith('final_compare') or row['build']=='scan_fit2':print(row)
