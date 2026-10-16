"""Extract actual Fitter metrics for the stopped P5 round, without prediction."""
import csv
import hashlib
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
RESULTS = HERE.parent / 'unified_scan/results'

def build_metrics(name):
    root = RESULTS / name / 'bcd'
    fit = (root / 'radar_unified_bcd.fit.rpt').read_text(encoding='utf-8', errors='replace')
    sta = (root / 'radar_unified_bcd.sta.summary').read_text(encoding='utf-8', errors='replace')
    modules = []
    for line in fit.splitlines():
        cells = [c.strip() for c in line.split(';')[1:-1]]
        if len(cells) == 13 and re.fullmatch(r'\d+ \(\d+\)', cells[1]):
            modules.append(dict(instance=cells[0], le_self=int(re.search(r'\((\d+)\)', cells[1])[1])))
    text = (root / 'radar_unified_bcd.sta.rpt').read_text(encoding='utf-8', errors='replace')
    counts = {key:int(re.search(r'; '+key+r'\s*; (\d+)', text)[1]) for key in (
        'Unconstrained Input Ports', 'Unconstrained Input Port Paths',
        'Unconstrained Output Ports', 'Unconstrained Output Port Paths')}
    le = sum(m['le_self'] for m in modules)
    setup = float(re.search(r"Type\s*: Setup 'clk'\s+Slack\s*:\s*([\d.-]+)", sta)[1])
    hold = float(re.search(r"Type\s*: Hold 'clk'\s+Slack\s*:\s*([\d.-]+)", sta)[1])
    return dict(build=str(root.relative_to(HERE.parent)), le=le, modules=modules,
                fitter='Successful' if re.search(r'; Fitter Status\s*; Successful', fit) else 'Failed',
                setup_ns=setup, hold_ns=hold, new_threshold_pass=(le<=1270 and setup>=1 and hold>0),
                unconstrained=counts)

baseline = build_metrics('p5a0_audit')
candidate = build_metrics('p5_step1_candidate')
assert baseline['le']==1089 and candidate['le']==1109
assert not candidate['new_threshold_pass']
for build in (baseline,candidate):
    label='retained' if build is baseline else 'failed_step1'
    with (HERE / 'delivery' / f'{label}_module_le.csv').open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['instance','le_self']);w.writeheader();w.writerows(build['modules'])
manifest=[]
for file in sorted((HERE / 'delivery').glob('*.pof')):
    manifest.append(dict(file=file.name, features='P5a-0 original: SW6 dual mode, readback, MIN6, 1 degree',
                         sha256=hashlib.sha256(file.read_bytes()).hexdigest()))
assert len(manifest)==1
data=dict(status='STOPPED: mandatory step1 setup slack below 1 ns; step1 reverted; steps2-7 not attempted',
          retained=baseline, failed_step1=candidate, successful_pofs=manifest,
          unconstrained_candidate_delta={k:candidate['unconstrained'][k]-v for k,v in baseline['unconstrained'].items()})
(HERE/'delivery/metrics.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in data.items() if k not in ('retained','failed_step1')},ensure_ascii=False,indent=2))
