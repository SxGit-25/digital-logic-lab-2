"""Parse actual TimeQuest reports, retaining auditable source reports."""
import argparse, csv, json, re
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('directory', type=Path)
a = p.parse_args()
d = a.directory
text = (d/'setup10.rpt').read_text(errors='replace')
paths = []
for block in re.split(r'(?=Path #\d+: Setup slack)', text)[1:]:
    def field(name):
        m = re.search(r';\s*'+re.escape(name)+r'\s*;\s*([^;\r\n]+)', block)
        return m.group(1).strip() if m else ''
    m = re.search(r';\s*Number of Logic Levels\s*;\s*;\s*(\d+)', block)
    data = re.search(r';\s+Data\s*;.*?\n;\s+IC\s*;\s*;\s*\d+\s*;\s*([\d.]+)\s*;\s*(\d+)', block, re.S)
    paths.append(dict(rank=len(paths)+1, slack_ns=field('Slack'), start=field('From Node'), end=field('To Node'), logic_levels=m.group(1) if m else '', routing_ns=data.group(1) if data else '', routing_percent=data.group(2) if data else ''))
if len(paths) != 10:
    raise SystemExit(f'Expected 10 setup paths, got {len(paths)}')
with (d/'setup10.csv').open('w', newline='', encoding='utf-8-sig') as f:
    writer=csv.DictWriter(f, fieldnames=paths[0]); writer.writeheader(); writer.writerows(paths)
ucp=(d/'unconstrained.rpt').read_text(errors='replace')
summary={}
for name,baseline in [('Illegal Clocks',0),('Unconstrained Clocks',0),('Unconstrained Input Ports',0),('Unconstrained Input Port Paths',0),('Unconstrained Output Ports',58),('Unconstrained Output Port Paths',456)]:
    m=re.search(r';\s*'+name+r'\s*;\s*(\d+)\s*;\s*(\d+)',ucp)
    if not m: raise SystemExit('Missing unconstrained field '+name)
    summary[name]={'setup':int(m[1]),'hold':int(m[2]),'baseline':baseline,'setup_delta':int(m[1])-baseline,'hold_delta':int(m[2])-baseline}
cdc=(d/'cdc_assertions.txt').read_text(errors='replace')
summary['CDC_PASS']=('CDC_FAILURES=0' in cdc and cdc.count('PASS ')==3)
(d/'postfit_summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
lines=['# Postfit 实测报告','', '|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|','|---|---|---|---|---|---|---|']
for r in paths: lines.append('|'+ '|'.join(str(r[k]).replace('|', r'\|') for k in r)+'%|')
lines += ['',f'CDC 三项断言：{"PASS" if summary["CDC_PASS"] else "FAIL"}。','', '|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|','|---|---|---|---|---|---|']
for name,r in summary.items():
    if isinstance(r,dict): lines.append('|'+name+'|'+'|'.join(str(v) for v in r.values())+'|')
(d/'postfit_summary.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False))
