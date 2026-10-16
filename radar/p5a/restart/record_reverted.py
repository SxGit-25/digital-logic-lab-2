"""Preserve unsuccessful whole-device attempts without inventing postfit timing."""
from pathlib import Path
import argparse,csv,json,re,shutil
ROOT=Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser()
p.add_argument('--step',type=int,required=True)
p.add_argument('--prefix',required=True)
p.add_argument('--previous',required=True)
p.add_argument('--feature',required=True)
p.add_argument('--regression-pass',type=Path,required=True)
p.add_argument('--notes',default='')
a=p.parse_args()
out=Path(__file__).parent/f'step{a.step}';out.mkdir(exist_ok=True)
builds=[]
for d in sorted((ROOT/'radar/unified_scan/results').glob(a.prefix+'*')):
    f=d/'bcd/radar_unified_bcd.fit.summary'
    if not f.exists(): continue
    t=f.read_text(errors='replace');m=re.search(r'Total logic elements\s*:\s*([\d,]+)',t)
    builds.append(dict(build=d.name,le_required=int(m[1].replace(',','')) if m else None,
                       fitter_success='Fitter Status : Successful' in t))
assert builds and not any(b['fitter_success'] for b in builds),builds
assert 'PASS' in a.regression_pass.read_text(encoding='utf-8-sig')
previous=json.loads((Path(__file__).parent/f'step{a.previous}'/'checkpoint.json').read_text(encoding='utf-8'))
record=dict(step=a.step,status='reverted',feature=a.feature,attempts=builds,
            retained_step=int(a.previous),le=previous['le'],setup_ns=previous['setup_ns'],
            hold_ns=previous['hold_ns'],setup_delta_ns=0,seed=previous['seed'],
            reason='资源超过1270LE，所有种子均未完成Fitter；无有效拟合后时序。',
            regression_pass=str(a.regression_pass),notes=a.notes)
record['modules']=previous['modules']
shutil.copy2(Path(__file__).parent/f'step{a.previous}'/'module_le.csv',out/'module_le.csv')
(out/'checkpoint.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (out/'attempts.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['build','le_required','fitter_success']);w.writeheader();w.writerows(builds)
# Report each entity's synthesis cell count for failed candidates. This is
# explicitly synthesis evidence, never described as a fitted LE measurement.
modules=[]
for b in builds:
    text=(ROOT/'radar/unified_scan/results'/b['build']/'bcd/radar_unified_bcd.map.rpt').read_text(errors='replace')
    for line in text.splitlines():
        c=[v.strip() for v in line.split(';')[1:-1]]
        if len(c)==13 and re.fullmatch(r'\d+ \(\d+\)',c[1]):
            modules.append(dict(build=b['build'],instance=c[11],synthesis_cells_self=int(re.search(r'\((\d+)\)',c[1])[1])))
with (out/'candidate_modules.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=['build','instance','synthesis_cells_self']);w.writeheader();w.writerows(modules)
name=f'step{a.step}_unchanged_after_{a.feature}_reverted_{previous["le"]}LE.pof'
shutil.copy2(Path(__file__).parent/'pofs'/previous['pof'],Path(__file__).parent/'pofs'/name)
record['pof']=name
(out/'checkpoint.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=[f'# 第{a.step}项：回退 {a.feature}', '',record['reason'], '',
       f'保留第{a.previous}项：{previous["le"]}LE，setup {previous["setup_ns"]:.3f}ns（相对上一保留版本变化0），hold {previous["hold_ns"]:.3f}ns；seed={previous["seed"]}。', '',
       '对失败候选实际执行report_timing，但TimeQuest拒绝在Fitter失败后建立时序网表；不能列出有效的最差10条拟合后路径。失败日志保留，未用其他版本路径冒充。各模块综合资源见candidate_modules.csv，不能当作实际拟合LE。', '',
       '保持上个成功版本的同步器首级三项断言PASS，未约束输出58/456相对冻结基线增减0。候选无法完成拟合，不能声称其拟合断言通过。', '',a.notes, '',
       '| 候选 | Fitter所需LE | Fitter |','|---|---:|---|']
lines += [f'| {b["build"]} | {b["le_required"]} | 失败 |' for b in builds]
lines += ['', '当前保留版本各模块实际拟合 LE（自身，不重复累计子模块）：', '', '|模块|LE|','|---|---:|']
lines += ['| `'+m['instance'].replace('|',r'\|')+'` | '+str(m['le_self'])+' |' for m in previous['modules']]
lines += ['',f'全部旧回归凭据：`{a.regression_pass}`。',f'另存POF `{name}`，与上个成功POF逐字节相同，文件名明确标注功能回退。','']
(out/'报告.md').write_text('\n'.join(lines),encoding='utf-8')
print(json.dumps(record,ensure_ascii=False))
