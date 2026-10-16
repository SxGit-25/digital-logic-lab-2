"""Read preserved Quartus reports; never compile or modify production RTL."""
from pathlib import Path
import csv, json, re, hashlib

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
RESULTS=ROOT/'radar/unified_scan/results'
BUILD_NAMES=['p5a0_audit','p5r_step3_alarm_gate','p5r_step4_initial','p5r_step4_shared','p5r_step4_area']+[f'p5r_step4_seed{i}' for i in range(2,9)]

def parse_table(path,title):
    lines=path.read_text(errors='replace').splitlines()
    begin=next(i for i,s in enumerate(lines) if s.startswith('; '+title+' '))
    rows=[]
    for number,line in enumerate(lines[begin+1:],begin+2):
        parts=[s.strip() for s in line.split(';')]
        if len(parts)<14 or not parts[1].startswith('|'):continue
        match=re.fullmatch(r'(\d+)\s*\((\d+)\)',parts[2])
        if not match:continue
        rows.append(dict(instance=parts[1],full_hierarchy=parts[12],
            le_subtree=int(match[1]),le_self=int(match[2]),registers_subtree=int(parts[3]),
            source=str(path.relative_to(ROOT)).replace('\\','/'),source_line=number))
    for row in rows:
        prefix=row['full_hierarchy']+'|'
        children=[r for r in rows if r['full_hierarchy'].startswith(prefix) and '|' not in r['full_hierarchy'][len(prefix):]]
        row['registers_self']=row['registers_subtree']-sum(r['registers_subtree'] for r in children)
    assert rows and sum(r['le_self'] for r in rows)==rows[0]['le_subtree']
    return rows

builds={}
for name in BUILD_NAMES:
    folder=RESULTS/name/'bcd'
    fit=folder/'radar_unified_bcd.fit.rpt'
    synthesis=folder/'radar_unified_bcd.map.rpt'
    fit_text=fit.read_text(errors='replace')
    rows=parse_table(fit,'Fitter Resource Utilization by Entity')
    status=re.search(r'; Fitter Status\s*;\s*([^;\r\n]+)',fit_text)[1].strip()
    map_rows=parse_table(synthesis,'Analysis & Synthesis Resource Utilization by Entity')
    qsf=folder/'source/lcd_p4/radar_unified_bcd.qsf'
    qsf_text=qsf.read_text(errors='replace')
    flags={key:int(m[1]) if (m:=re.search(r'set_parameter -name '+key+r'\s+(\d+)',qsf_text)) else None for key in ('P5_UFM','P5_INVERT','P5_BEAM')}
    seed=int(re.search(r'set_global_assignment -name SEED\s+(\d+)',qsf_text)[1]) if 'name SEED' in qsf_text else None
    builds[name]=dict(status=status,successful=status.startswith('Successful'),seed=seed,
        measurement='Fitter完成布局布线的LE' if status.startswith('Successful') else '失败Fitter报告的打包后逻辑单元需求；未完成布局布线',
        total_le=rows[0]['le_subtree'],total_registers=rows[0]['registers_subtree'],flags=flags,
        fit_rows=rows,map_total_cells=map_rows[0]['le_subtree'],map_rows=map_rows,
        fit_report_sha256=hashlib.sha256(fit.read_bytes()).hexdigest())

base=builds['p5a0_audit'];current=builds['p5r_step3_alarm_gate'];beam=builds['p5r_step4_initial']
lookup={b:{r['full_hierarchy']:r for r in builds[b]['fit_rows']} for b in ('p5a0_audit','p5r_step3_alarm_gate','p5r_step4_initial')}
comparison=[]
for full in sorted(set().union(*(set(x) for x in lookup.values()))):
    found={name:lookup[name].get(full) for name in lookup}
    row=dict(instance=full)
    for name,prefix in [('p5a0_audit','baseline1089'),('p5r_step3_alarm_gate','current1253'),('p5r_step4_initial','failed1321')]:
        r=found[name]
        row[prefix+'_fitter_self_le']=r['le_self'] if r else 0
        row[prefix+'_registers_self']=r['registers_self'] if r else 0
    row['current_minus_baseline_le']=row['current1253_fitter_self_le']-row['baseline1089_fitter_self_le']
    row['failed_minus_current_le']=row['failed1321_fitter_self_le']-row['current1253_fitter_self_le']
    row['failed_minus_current_registers']=row['failed1321_registers_self']-row['current1253_registers_self']
    comparison.append(row)

register_additions=[dict(module='radar_lcd_micro',name=n,width=w) for n,w in
 [('draw_mode',1),('beam_valid',1),('beam_drawn_angle',8),('request_angle_bin',8),('beam_len',6),('beam_phase',2)]]
register_additions.append(dict(module='radar_unified_top',name='lcd_restart_pending',width=1))
ledger=dict(builds=builds,module_comparison= comparison,rtl_named_register_additions=register_additions,
 notes=['失败Fitter的Resource Usage Summary为Not available，但其Utilization by Entity表确实可得；不能称其已成功fit。',
 'MAP是综合逻辑单元，单独存储并明确标记；不作为实际Fitter LE比较。',
 '旧beam有动态beam_len与stop协议；本账不把旧功能要求自动带入beam-min新目标。'])
(OUT/'ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
with (OUT/'ledger.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(comparison[0]));w.writeheader();w.writerows(comparison)

def esc(s):return str(s).replace('|',r'\|')
lines=['# LE 账：1089 → 1253 → 上轮 1321 扫描线候选','',
 '**当前实际保留版本为 1253 LE；相对原 1089 增加 164 LE。旧扫描线候选的失败 Fitter 确认需求 1321 LE，较 1253 增加 68，超器件 1270 上限 51。**','',
 '## 口径与证据','',
 '- 1089、1253 均取成功 Fitter 的 `Fitter Resource Utilization by Entity`，括号内数为模块自身 LE。',
 '- 1321 虽然 Fitter 失败，仍有上述层级资源表（fit.rpt:443，表格首行:447），可提取打包后的 LE 需求；未完成放置布线，不能称为成功 fit 或给出有效 postfit slack。',
 '- 同一失败报告的 `Fitter Resource Usage Summary`（:139）总 LE 写 `Not available`，但 Fitter Summary（:60）和层级总计（:447）明确为1321。报错（:770）为1321 logic cells超过1270。',
 '- 旧 `p5a/restart/step4/candidate_modules.csv` 来自 MAP，综合总数1404、draw self516；本账不用它冒充 Fitter LE。实际失败 Fitter 为1321、draw self468。','',
 '|模块（自身，不重复算子层）|1089成功FIT|1253成功FIT|变化|1321失败FIT需求|较1253|','|---|---:|---:|---:|---:|---:|']
for r in comparison:
    short=r['instance'].split('|')[-1]
    lines.append('|'+ '|'.join(map(esc,[short,r['baseline1089_fitter_self_le'],r['current1253_fitter_self_le'],r['current_minus_baseline_le'],r['failed1321_fitter_self_le'],r['failed_minus_current_le']]))+'|')
lines+=['|合计|1089|1253|+164|1321|+68|','',
 '绘图整个子树（含 datapath、reader）395 → 571 → 645，分别 +176、+74；自身 draw 283 →391 →468。1253 至旧 beam：draw自身+77、其datapath-3、reader不变，子树净+74；绘图子树以外模块净-6，故全机净+68。若只排除draw自身，其余全机模块合计为-9。',
 '', '## 旧扫描线尝试','', '|build|seed|Fitter需求LE|Fitter|MAP综合cells|反显 P5_INVERT|','|---|---:|---:|---|---:|---:|']
for name in BUILD_NAMES[2:]:
    b=builds[name];lines.append(f'|{name}|{b["seed"]}|{b["total_le"]}|失败|{b["map_total_cells"]}|{b["flags"]["P5_INVERT"]}|')
lines += ['', '初版1321；共享地址/返回角尝试1328；USER-ENCODED FSM + AREA尝试1368。初版为 seed1，其后 seed2–8均1321。全部保留 `P5_UFM=1`、`P5_INVERT=1`、`P5_BEAM=1`，没有通过删除反显来得到1321。',
 '', '## 寄存器账','', '|旧beam新增RTL字段|位数|用途|','|---|---:|---|']
purpose={'draw_mode':'本次请求的模式快照','beam_valid':'上次线存在标志','beam_drawn_angle':'撤线角度','request_angle_bin':'撤旧线期间保存新请求角度','beam_len':'旧方案动态线长','beam_phase':'撤旧/正常/画新阶段','lcd_restart_pending':'模式切换stop锁存直至可复位'}
for r in register_additions:lines.append(f'|{r["module"]}.{r["name"]}|{r["width"]}|{purpose[r["name"]]}|')
lines += ['', '上述新增命名字段共27 RTL位（draw26，top1）。Fitter全机寄存器统计437 →528 →557；旧beam较1253多29个寄存器需求，其中draw自身112→140（+28）、top自身0→1。命名RTL位不能逐位当成最终LE；另外2个寄存器差异可能来自FSM实现/优化，尚无逐节点网表归因，不作确定归属。失败版本未完成物理布局。',
 '', '当前1253至1270仅余17 LE。旧beam的68 LE增量包含动态长度、请求返回角和停止协议的控制，不是新最简固定线长方案的实测预测；新候选仍须整机Fitter测量。',
 '', '## 源报告','']
for name in ('p5a0_audit','p5r_step3_alarm_gate','p5r_step4_initial'):
    row=builds[name]['fit_rows'][0];lines.append(f'- `{row["source"]}:{row["source_line"]}`；保存的综合/MAP与源QSF分别在同一build目录。')
lines += ['', '提取脚本 `ledger_extract.py` 仅读保存报告与源快照，未编译、未改生产RTL。JSON保留所有模块的来源行号、Fitter状态、原始MAP口径及报告SHA-256。']
(OUT/'LE账.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print(json.dumps({'current':current['total_le'],'beam_failed_fitter':beam['total_le'],'delta':beam['total_le']-current['total_le'],'modules':len(comparison)},ensure_ascii=False))
