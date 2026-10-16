"""Summarize the unchanged P5a-0 build; keep every unconstrained path visible."""
import csv
import hashlib
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
RESULTS = ROOT / 'unified_scan/results'
BUILD = RESULTS / 'p5a0_audit/bcd'

def read(path):
    return path.read_text(encoding='utf-8-sig', errors='replace')

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

fit = read(BUILD / 'radar_unified_bcd.fit.rpt')
resource_rows = []
in_table = False
for line in fit.splitlines():
    if line.startswith('; Fitter Resource Utilization by Entity'):
        in_table = True
    if in_table and line.startswith('Note:'):
        break
    cells = [c.strip() for c in line.split(';')[1:-1]]
    if in_table and len(cells) == 13 and re.fullmatch(r'\d+ \(\d+\)', cells[1]):
        resource_rows.append(dict(instance=cells[0], le_self=int(re.search(r'\((\d+)\)', cells[1])[1]),
                                  le_subtree=int(cells[1].split()[0]), registers_subtree=int(cells[2])))
assert sum(r['le_self'] for r in resource_rows) == 1089
with (OUT / 'module_resources.csv').open('w', encoding='utf-8-sig', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(resource_rows[0])); w.writeheader(); w.writerows(resource_rows)

analysis = section = None
paths = []
for line in read(BUILD / 'p5a0_unconstrained.rpt').splitlines():
    cells = [c.strip() for c in line.split(';')[1:-1]]
    if cells == ['Setup Analysis']: analysis = 'setup'
    if cells == ['Hold Analysis']: analysis = 'hold'
    if len(cells) == 1: section = cells[0]
    if analysis and section in ('Unconstrained Input Port Paths', 'Unconstrained Output Port Paths') and len(cells) == 3 and cells[0] != 'From':
        source, target, clocks = cells
        if section == 'Unconstrained Input Port Paths':
            explanation = ('原始异步 SW7 即时关断门控到寄存器；未定义输入到该寄存器的时限；不属于已豁免的同步首级，不能由正 slack 签核。'
                           if clocks else '原始异步 SW7 直接门控板外输出；无外部到达/接收时限，未作板级签核。')
        elif target == 'servo':
            explanation = '舵机 PWM 输出无外部 delay；1 us 计数节拍、20 ms 帧；本轮保留未约束并说明，未新增 false path。'
        elif target == 'trig':
            explanation = '超声 TRIG 输出无外部 delay；1 us 节拍、约15 us 高脉冲；本轮保留未约束并说明，未新增 false path。'
        elif target == 'buzzer':
            explanation = '蜂鸣器无同步接收时钟、无输出 delay；2 kHz 载波（250 us 半周期）；无严格外部时序签核。'
        elif target.startswith('led'):
            explanation = 'LED 视觉输出无外部 delay；报警2 Hz闪烁，不存在已定义的同步接收边沿；无板级负载签核。'
        else:
            explanation = '数码管/点阵视觉输出无外部 delay；250 us 扫描步长、约40 ns消隐；没有负载/驱动级时序约束，不能保证全部板外建立保持。'
        paths.append(dict(analysis=analysis, kind='input' if 'Input' in section else 'output', source=source,
                          target=target, clocks=clocks, explanation=explanation))
counts = Counter((p['analysis'], p['kind']) for p in paths)
assert counts == {('setup','input'):140, ('setup','output'):456, ('hold','input'):140, ('hold','output'):456}, counts
with (OUT / 'unconstrained_paths.csv').open('w', encoding='utf-8-sig', newline='') as f:
    w = csv.DictWriter(f, fieldnames=list(paths[0])); w.writeheader(); w.writerows(paths)

with (RESULTS / 'p5a0_draw/budget_f15/busy_walltime.csv').open(encoding='utf-8-sig') as f:
    timings = [{k:int(v) for k,v in r.items()} for r in csv.DictReader(f)]

def frame(row):
    pixels = row['rmw_pixels']
    # Each pixel: six writes of 16 clocks, two reads of 40 clocks.
    write_ns = pixels * 6 * 16 * 20
    read_ns = pixels * 2 * 40 * 20
    return dict(**row, ufm_ns=0, lcd_write_ns=write_ns, lcd_read_ns=read_ns,
                state_arithmetic_handshake_ns=row['busy_ns']-write_ns-read_ns,
                margin_to_continuous_60ms_ns=60_000_000-row['busy_ns'])

same = []
for r in csv.DictReader((BUILD / 'source_sha256.csv').open(encoding='utf-8-sig')):
    relative = r['File']
    source = ROOT / ('rtl/' + relative[4:] if relative.startswith('rtl/') else 'unified_scan/' + relative[7:])
    # Build QSF has AREA options appended by the existing compile script.
    if source.suffix == '.v':
        assert digest(source).upper() == r['SHA256'].upper(), source
        baseline = RESULTS / 'budget_final_index/bcd/source' / relative
        assert digest(source) == digest(baseline), source
        same.append(relative)

summary = dict(checkpoint='P5a-0 audit; hardware acceptance pending; SW6/SW7 false-path policy conflict open',
               source_commit='c2d5025', rtl_identical_to_1089_baseline=same,
               le_total=1089, registers=437, fitter='Successful', setup_ns=3.786, hold_ns=1.078,
               unconstrained_counts={f'{a}_{k}':n for (a,k),n in counts.items()},
               ordinary_worst=frame(max((r for r in timings if r['erase_rays']!=11),key=lambda r:r['busy_ns'])),
               endpoint_worst=frame(max(timings,key=lambda r:r['busy_ns'])),
               source_pof_sha256=digest(RESULTS/'budget_final_index/bcd/radar_unified_bcd.pof'),
               rebuilt_pof_sha256=digest(BUILD/'radar_unified_bcd.pof'))
(OUT/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
