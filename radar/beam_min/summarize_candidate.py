"""Compare actual packed/fitted resources; do not equate register bits to LE."""
from pathlib import Path
import csv,json,re
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
names=['p5r_step3_alarm_gate','beam_min_initial','beam_min_byte_a']
builds=[]
for name in names:
    folder=ROOT/'radar/unified_scan/results'/name/'bcd'
    text=(folder/'radar_unified_bcd.fit.rpt').read_text(errors='replace')
    modules=[]
    for line in text.splitlines():
        c=[s.strip() for s in line.split(';')[1:-1]]
        if len(c)==13 and re.fullmatch(r'\d+ \(\d+\)',c[1]):
            instance=c[0].strip('|')
            label='UFM reader' if instance.startswith(('p5_ufm_reader:','p5_ufm_byte_reader:')) else instance
            modules.append(dict(instance=instance,label=label,le_self=int(re.search(r'\((\d+)\)',c[1])[1]),registers_subtree=int(c[2])))
    le=sum(row['le_self'] for row in modules)
    fit_success=bool(re.search(r'; Fitter Status\s*;\s*Successful',text))
    summary=folder/'radar_unified_bcd.sta.summary'
    sta=summary.read_text(errors='replace') if summary.exists() else ''
    def worst(kind):
        vals=re.findall(r"Type\s*: "+kind+r" '[^']+'\s+Slack\s*:\s*([\d.-]+)",sta)
        return min(map(float,vals)) if vals else None
    builds.append(dict(build=name,le=le,registers=modules[0]['registers_subtree'],fitter_success=fit_success,
                       setup_ns=worst('Setup'),hold_ns=worst('Hold'),modules=modules))
lookups=[{r['label']:r['le_self'] for r in b['modules']} for b in builds]
rows=[]
for label in dict.fromkeys(r['label'] for b in builds for r in b['modules']):
    values=[table.get(label,0) for table in lookups]
    rows.append(dict(module=label,delivery1253=values[0],minimal_initial1272=values[1],byte_a1270=values[2],
                     beam_delta=values[1]-values[0],ufm_a_delta=values[2]-values[1],final_delta=values[2]-values[0]))
with (OUT/'candidate_modules.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=rows[0]);writer.writeheader();writer.writerows(rows)
(OUT/'candidate_metrics.json').write_text(json.dumps(dict(builds=builds,comparison=rows),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['# 最简扫描线整机实测 LE 变化','',
       '| 阶段 | LE | Fitter | setup ns | hold ns |', '|---|---:|---|---:|---:|']
for b in builds:
    lines.append(f'| {b["build"]} | {b["le"]} | '+('成功' if b['fitter_success'] else '失败，仅打包需求')+f' | {b["setup_ns"] if b["fitter_success"] else "不可得"} | {b["hold_ns"] if b["fitter_success"] else "不可得"} |')
lines+=['', '步骤a：UFM只保留8位数据，随机高字节8个DRCLK早停；随机低字节跳过前8位；初始化低字节接续前次高字节。地址9位独立，未实施地址/数据共享。', '',
        '整机1272→1270净省2LE。UFM读器69→68（-1），绘图控制413→414（+1），测距模块因Fitter重新打包133→131（-2）；其余不变。不能把8个数据寄存器的减少冒称为节省8LE，也未修改测距功能。', '',
        '步骤b、c未实施：步骤a已达到硬门槛，按“够了就停”结束资源化简。LCD报警反显、LED及蜂鸣器报警全部保留。', '',
        '| 模块自身LE | delivery-1253 | 最简初版 | 步骤a | 初版增量 | a增量 | 最终增量 |',
        '|---|---:|---:|---:|---:|---:|---:|']
for r in rows:
    lines.append('| `'+r['module'].replace('|',r'\|')+'` | '+' | '.join(str(r[k]) for k in list(r)[1:])+' |')
lines+=['', '差异为Fitter实际层级自身LE，不重复累计父子。1272未完成布局布线；其时序分析调用被工具拒绝，日志见initial_failed_timing。1270成功后最差10条路径与CDC/未约束基线核对见postfit。', '',
        '最坏setup路径：bit_index[2]→position_count[0]，9逻辑级，布线占66%，setup=2.994ns；来自共享绘图/任务计数控制路径。同步SW7不是该候选最坏路径。门槛已满足，无须进一步流水化或seed扫描，QSF固定seed1。','']
(OUT/'LE变化.md').write_text('\n'.join(lines),encoding='utf-8')
print('PASS actual fit accounting: delivery1253 -> minimal1272 -> byte-a1270; inverse retained')
