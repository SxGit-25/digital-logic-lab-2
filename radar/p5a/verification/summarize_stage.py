"""Extract the retained stage evidence without changing pass/fail policy."""
from pathlib import Path
import argparse,csv,json
p=argparse.ArgumentParser();p.add_argument('stage',type=Path);a=p.parse_args()
try:
    status=list(csv.DictReader((a.stage/'status.csv').open(encoding='utf-8')))
except UnicodeDecodeError:
    # The first Windows run wrote its CSV using the system CP936 default.
    status=list(csv.DictReader((a.stage/'status.csv').open(encoding='cp936')))
summary={'stage':a.stage.name,'pass':(a.stage/'PASS.txt').exists(),'suites':status,'frames':[]}
for row in status:
    evidence=Path(row['Evidence'])
    for file in evidence.rglob('busy_walltime.csv'):
        frames=list(csv.DictReader(file.open(encoding='utf-8')))
        if not frames:continue
        maximum=max(frames,key=lambda r:int(r['busy_ns']))
        summary['frames'].append({'file':str(file),'requests':len(frames),'worst_ns':int(maximum['busy_ns']),'margin_to_60ms_ns':60000000-int(maximum['busy_ns'])})
(a.stage/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'pass':summary['pass'],'suites':len(status),'frames':summary['frames']},ensure_ascii=False))
