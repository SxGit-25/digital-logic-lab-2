"""Read real whole-device reports and freeze a successful P5 checkpoint."""
from pathlib import Path
import argparse,csv,hashlib,json,re,shutil
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser()
p.add_argument('--step',type=int,required=True)
p.add_argument('--build',required=True)
p.add_argument('--previous',default='p5a0_audit')
p.add_argument('--features',required=True)
p.add_argument('--regression-pass',type=Path,required=True)
p.add_argument('--seed',type=int,default=1)
p.add_argument('--notes',default='')
a=p.parse_args()
def metrics(build):
    d=ROOT/'radar/unified_scan/results'/build/'bcd'
    fit=(d/'radar_unified_bcd.fit.rpt').read_text(encoding='utf-8-sig',errors='replace')
    sta=(d/'radar_unified_bcd.sta.summary').read_text(encoding='utf-8-sig',errors='replace')
    modules=[]
    for line in fit.splitlines():
        c=[x.strip() for x in line.split(';')[1:-1]]
        if len(c)==13 and re.fullmatch(r'\d+ \(\d+\)',c[1]):
            modules.append(dict(instance=c[0],le_self=int(re.search(r'\((\d+)\)',c[1])[1])))
    setup=[float(x) for x in re.findall(r"Type\s*: Setup '[^']+'\s+Slack\s*:\s*([\d.-]+)",sta)]
    hold=[float(x) for x in re.findall(r"Type\s*: Hold '[^']+'\s+Slack\s*:\s*([\d.-]+)",sta)]
    assert setup and hold
    le=sum(x['le_self'] for x in modules)
    return dict(build=build,le=le,fitter_success=bool(re.search(r'; Fitter Status\s*; Successful',fit)),
                setup_ns=min(setup),hold_ns=min(hold),modules=modules)
current=metrics(a.build);prev=metrics(a.previous)
assert current['fitter_success'] and current['le']<=1270 and current['setup_ns']>0 and current['hold_ns']>0,current
assert a.regression_pass.is_file() and 'PASS' in a.regression_pass.read_text(encoding='utf-8-sig'),a.regression_pass
out=HERE/f'step{a.step}';out.mkdir(parents=True,exist_ok=True)
src=ROOT/'radar/unified_scan/results'/a.build/'bcd/radar_unified_bcd.pof'
pofs=HERE/'pofs';pofs.mkdir(exist_ok=True)
name=f'step{a.step}_{a.features}_{current["le"]}LE.pof'
shutil.copy2(src,pofs/name)
if not (pofs/'step0_original_SW6_readback_1089LE.pof').exists():
    shutil.copy2(ROOT/'radar/unified_scan/results/p5a0_audit/bcd/radar_unified_bcd.pof',pofs/'step0_original_SW6_readback_1089LE.pof')
record=dict(step=a.step,features=a.features,seed=a.seed,**current,
            previous_build=a.previous,le_delta=current['le']-prev['le'],
            setup_delta_ns=round(current['setup_ns']-prev['setup_ns'],3),
            setup_target_pass=current['setup_ns']>=1,regression_pass=str(a.regression_pass),
            pof=name,pof_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),notes=a.notes)
(out/'checkpoint.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (out/'module_le.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['instance','le_self']);w.writeheader();w.writerows(current['modules'])
lines=[f'# 第{a.step}项检查点', '',f'保留：{a.features}；seed={a.seed}。', '',
       f'整机 {current["le"]} LE（较上一保留项 {record["le_delta"]:+d}），Fitter 成功；setup {current["setup_ns"]:.3f} ns（变化 {record["setup_delta_ns"]:+.3f} ns），hold {current["hold_ns"]:.3f} ns。', '',a.notes,'',
       '| 模块 | 自身 LE |','|---|---:|']
lines += [f'| `{m["instance"]}` | {m["le_self"]} |' for m in current['modules']]
lines += ['',f'全部既有回归通过凭据：`{a.regression_pass}`。',f'POF：`../pofs/{name}`；SHA-256 `{record["pof_sha256"]}`。','']
(out/'报告.md').write_text('\n'.join(lines),encoding='utf-8')
print(json.dumps({k:v for k,v in record.items() if k!='modules'},ensure_ascii=False))
