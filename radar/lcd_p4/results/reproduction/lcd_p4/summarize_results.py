"""Extract actual packed Fitter demands, retaining failed-fit status explicitly."""
import csv
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results'
variants = []
modules = []
for variant in ('ufm8', 'case8', 'ufm7', 'case7', 'safe'):
    folder = OUT / variant
    fit = next(folder.glob('*.fit.rpt')).read_text(errors='replace')
    section = fit[fit.index('; Fitter Resource Utilization by Entity'):]
    rows = []
    for line in section.splitlines():
        cells = [c.strip() for c in line.split(';')]
        if len(cells) < 14 or not cells[1].startswith('|'):
            continue
        if not re.match(r'\d+', cells[2]):
            continue
        number = lambda s: int(re.match(r'\d+', s).group())
        own = re.search(r'\((\d+)\)', cells[2])
        row = dict(variant=variant, node=cells[1], le_including_children=number(cells[2]),
                   le_self=int(own.group(1)) if own else number(cells[2]),
                   registers=number(cells[3]), ufm=number(cells[4]), pins=number(cells[5]))
        rows.append(row)
    top = rows[0]
    modules.extend(rows)
    mapping = next(folder.glob('*.map.summary')).read_text()
    mapped_le = int(re.search(r'Total logic elements\s*:\s*([\d,]+)', mapping).group(1).replace(',', ''))
    timing = next(folder.glob('*.sta.summary'), None)
    slacks = {}
    if timing:
        for name, value in re.findall(r'Type\s*:\s*(.*?)\r?\nSlack\s*:\s*([\d.-]+)', timing.read_text()):
            slacks[name] = float(value)
    variants.append(dict(variant=variant, legal_fit=variant == 'safe', polar_graph=variant != 'safe',
                         mapped_le=mapped_le, fitter_le=top['le_including_children'],
                         registers=top['registers'], pins=top['pins'], ufm=top['ufm'],
                         delta_p3_le=top['le_including_children']-1033,
                         over_budget_le=top['le_including_children']-1143,
                         timing_slack_ns=slacks,
                         status='fit succeeds; no readback/graph; exceeds 1143' if variant=='safe' else
                                'fit fails: exceeds EPM1270 capacity; no valid fitted timing'))
with (OUT/'module_resources.csv').open('w',newline='',encoding='utf-8-sig') as f:
    writer=csv.DictWriter(f,fieldnames=list(modules[0]));writer.writeheader();writer.writerows(modules)
(OUT/'resource_comparison.json').write_text(json.dumps(variants,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps(variants,indent=2))
