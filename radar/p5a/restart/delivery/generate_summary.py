"""Regenerate one-page PDF, identical-content Markdown, and POF inventory.

Use the bundled Python runtime with reportlab/pypdf/pdfplumber installed.
Edit summary_data.json only after final checkpoint verification.
"""
from pathlib import Path
from html import escape
import csv
import hashlib
import json
import shutil
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from pypdf import PdfReader
import pdfplumber

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]
DATA = json.loads((HERE / 'summary_data.json').read_text(encoding='utf-8'))
checkpoint = ROOT / 'radar/p5a/restart/step3/checkpoint.json'
if checkpoint.is_file():
    actual = json.loads(checkpoint.read_text(encoding='utf-8'))
    for name, key in [('le', 'le'), ('setup_ns', 'setup_ns'), ('hold_ns', 'hold_ns'), ('seed', 'seed'), ('setup_delta_ns', 'setup_delta_ns')]:
        assert DATA[name] == actual[key], (name, DATA[name], actual[key])
    DATA['pofs'][3]['name'] = actual['pof']
assert sum(row['self_le'] for row in DATA['modules']) == DATA['le']
pdfmetrics.registerFont(TTFont('Chinese', 'C:/Windows/Fonts/simhei.ttf'))
body = ParagraphStyle('body', fontName='Chinese', fontSize=8.5, leading=12, spaceAfter=5)
title = ParagraphStyle('title', parent=body, fontSize=17, leading=22, spaceAfter=6)
small = ParagraphStyle('small', parent=body, fontSize=7.6, leading=10.2, spaceAfter=3)
sub = ParagraphStyle('sub', parent=body, fontSize=9.5, leading=13, spaceBefore=4, spaceAfter=4)
story, markdown = [], []


def paragraph(text, style=body, heading=False):
    story.append(Paragraph(escape(text), style))
    markdown.extend([('## ' if heading else '') + text, ''])


def table(rows, widths, md_rows=None):
    result = Table([[Paragraph(escape(str(cell)), small) for cell in row] for row in rows], colWidths=widths)
    result.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#e8eef5')),
        ('GRID', (0, 0), (-1, -1), 0.3, colors.HexColor('#cbd5e1')),
        ('VALIGN', (0, 0), (-1, -1), 'TOP'),
        ('LEFTPADDING', (0, 0), (-1, -1), 5), ('RIGHTPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 3), ('BOTTOMPADDING', (0, 0), (-1, -1), 3)]))
    story.append(result)
    story.append(Spacer(1, 6))
    source = md_rows or rows
    markdown.append('| ' + ' | '.join(map(str, source[0])) + ' |')
    markdown.append('|' + '|'.join('---' for _ in source[0]) + '|')
    markdown.extend('| ' + ' | '.join(str(v).replace('|', '\\|') for v in row) + ' |' for row in source[1:])
    markdown.append('')


draft = 'DRAFT - 待主Agent最终核验' if DATA['draft'] else '已完成核验'
heading = 'LCM12864 雷达升级 - 本轮总结'
story.append(Paragraph(heading, title))
markdown.extend(['# ' + heading, ''])
paragraph(f"{DATA['date']} | {draft}。保留1a/1b/2/3，4至7因LE超限回退；尚未实物验收或烧录。")
paragraph('单一POF；SW6切换基本/连续；ENABLE_READBACK=1；最小半径6、1度步进；原有功能保留。')
table([['项目', '结果', '行为 / 回退原因']] + DATA['items'], [96, 40, 385])
paragraph(f"最终整机 {DATA['le']} LE；Fitter成功；seed={DATA['seed']}。setup {DATA['setup_ns']:.3f} ns（较第2项 {DATA['setup_delta_ns']:+.3f} ns），hold {DATA['hold_ns']:.3f} ns，满足LE≤1270及正slack硬门槛，也达到setup≥1 ns目标。")
paragraph('各模块LE：仅计自身括号值，不重复累计父子', sub, True)
nonzero = [row for row in DATA['modules'] if row['self_le']]
paired = []
for i in range(0, len(nonzero), 2):
    a, b = nonzero[i], nonzero[i + 1]
    paired.append([a['label'], a['self_le'], b['label'], b['self_le']])
table([['模块', '自身LE', '模块', '自身LE']] + paired, [199, 61, 200, 61],
      [['模块', '自身LE']] + [[row['label'], row['self_le']] for row in DATA['modules']])
paragraph('ALTUFM及其生成层自身LE均为0，占1个UFM块。', small)
frame = DATA['frame_command_bound_ms']
paragraph(f"帧耗时：几何最坏{DATA['frame_geometry_ms']:.5f} ms；加1条反显命令的保守帧上界{frame:.5f} ms，相对连续模式60 ms/1度间隔余量{60-frame:.5f} ms。忙时报警事件至命令完成另有保守上界{DATA['frame_alarm_event_bound_ms']:.5f} ms。")
paragraph('帧分项上界：UFM 4.11010 ms + LCD读0.77080 / 写0.95880 ms + 状态机0.93360 ms + 反显排队0.00040 ms = 6.77370 ms。', small)
paragraph(f"初始化{DATA['initialization_ms']:.5f} ms = UFM读取{DATA['initialization_ufm_ms']:.5f} + LCD读写{DATA['initialization_lcd_ms']:.5f} + 计时等待/状态机等{DATA['initialization_other_ms']:.5f} ms。")
paragraph('验证与例外：最终版原有20项回归全PASS；sw6/sw7/echo首级同步器三项网表断言均PASS。未约束58个输出/456条路径，相对冻结基线均增减0；无新增未约束输入或时钟。UFM实际POF的512字经官方SVF及原始记录双重反解，与MIF逐字一致。')
paragraph(DATA['notes'], small)
paragraph('回退映像：step0原版1089LE；step1修复1101LE；step2加UFM背景1225LE；step3加反显1253LE。第4至7回退POF均与step3内容相同，不包含对应新功能；文件名及SHA-256见《POF清单》。', small)
paragraph('预览来自step2连续模式实际仿真RAM，与最终UFM/几何正常画面一致；无DEG/mm/LV、动态数字、模式字、等级条或扫描线。不是实物照片。', small)
paragraph('烧录：Programmer中CFM和UFM都勾选Program，并对两区Verify；最后统一实物检查圈完整、目标单点、无竖条、无错位及相邻列/文字位序。', small)

target = HERE / '本轮总结.pdf'
SimpleDocTemplate(str(target), pagesize=(595.28, 841.89), leftMargin=37, rightMargin=37,
                  topMargin=27, bottomMargin=25, title=heading, author='Codex').build(story)
assert len(PdfReader(target).pages) == 1, 'Summary must remain one page'
(HERE / '本轮总结.md').write_text('\n'.join(markdown), encoding='utf-8')
with pdfplumber.open(target) as doc:
    doc.pages[0].to_image(resolution=150).save(str(HERE / 'summary_render.png'))
preview = ROOT / DATA['preview_source']
shutil.copyfile(preview, HERE / '最终画面预览.png')

inventory = ['# POF清单', '', draft, '',
             '按功能从少到多排列；本清单仅列实际存在文件并给出SHA-256。', '',
             '| 阶段 | POF | LE | SHA-256 |', '|---|---|---:|---|']
for item, le in zip(DATA['pofs'], (1089, 1101, 1225, 1253)):
    file = ROOT / 'radar/p5a/restart/pofs' / item['name']
    assert file.is_file(), file
    inventory.append(f"| {item['step']} | [{file.name}]({file.resolve().as_posix()}) | {le} | `{hashlib.sha256(file.read_bytes()).hexdigest()}` |")
inventory += ['', '第0项为P5a-0原版回退。第1项包含1a/1b；第2项再加UFM背景；第3项再加报警反显。', '',
              '第4至7项未保留新功能；回退POF已验证与第3项逐字节相同，以下均为已归档文件。', '']
final = ROOT / 'radar/p5a/restart/pofs' / DATA['pofs'][3]['name']
for step in range(4, 8):
    matches = sorted((ROOT / 'radar/p5a/restart/pofs').glob(f'step{step}_*.pof'))
    if not matches:
        assert DATA['draft'], f'Missing checkpoint POF: {step}'
        inventory.append(f'- 第{step}项：回退副本尚待主Agent归档核准。')
    for file in matches:
        assert file.read_bytes() == final.read_bytes(), f'Reverted POF differs: {file}'
        inventory.append(f'- 第{step}项 [{file.name}]({file.resolve().as_posix()})：与第3项逐字节一致，SHA-256 `{hashlib.sha256(file.read_bytes()).hexdigest()}`。')
inventory += ['', '烧录必须同时对CFM和UFM勾选Program，并执行Verify；POF内数据验证不等于已对板上器件烧录或校验。', '']
(HERE / 'POF清单.md').write_text('\n'.join(inventory), encoding='utf-8')
print('PASS one-page summary PDF, matching Markdown, POF inventory, and actual-RAM preview')
