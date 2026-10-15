"""Extract every measured optimization round without inventing failed-fit timing."""
import csv
import json
import re
from pathlib import Path

OUT=Path(__file__).resolve().parent/'results'
summary=[];modules=[]
for report in sorted(OUT.glob('*/*/*.fit.rpt')):
    folder=report.parent;variant=folder.name;round_name=folder.parent.name
    text=report.read_text(errors='replace').split('; Fitter Resource Utilization by Entity')[1]
    rows=[]
    for line in text.splitlines():
        c=[v.strip() for v in line.split(';')]
        if len(c)<14 or not c[1].startswith('|') or not re.match(r'\d+',c[2]):continue
        num=lambda s:int(re.match(r'\d+',s).group())
        own=re.search(r'\((\d+)\)',c[2])
        rows.append(dict(round=round_name,variant=variant,module=c[1],le_total=num(c[2]),
                         le_self=int(own.group(1)) if own else num(c[2]),
                         registers=num(c[3]),ufm=num(c[4]),pins=num(c[5])))
    assert sum(r['le_self'] for r in rows)==rows[0]['le_total']
    modules+=rows
    fit=next(folder.glob('*.fit.summary')).read_text()
    legal='Fitter Status : Successful' in fit
    timing=next(folder.glob('*.sta.summary'),None)
    slacks=dict((name,float(value)) for name,value in re.findall(r'Type\s*:\s*(.*?)\r?\nSlack\s*:\s*([\d.-]+)',timing.read_text())) if timing else {}
    baseline=1186 if variant=='safe' else 1675 if 'case' in variant else 1664
    summary.append(dict(round=round_name,variant=variant,legal_fit=legal,polar_graph=variant!='safe',
                        fitter_le=rows[0]['le_total'],registers=rows[0]['registers'],io=rows[0]['pins'],ufm=rows[0]['ufm'],
                        baseline_f4507a8_le=baseline,delta_f4507a8=rows[0]['le_total']-baseline,over_budget=rows[0]['le_total']-1143,
                        timing_slack_ns=slacks))
with (OUT/'module_resources.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(modules[0]));w.writeheader();w.writerows(modules)
(OUT/'resource_comparison.json').write_text(json.dumps(summary,indent=2)+'\n')
for row in summary:
    print(row)
