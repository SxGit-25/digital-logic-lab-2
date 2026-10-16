"""Render the stopped round as a single A4 review page."""
import json
from pathlib import Path
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, Table, TableStyle, Spacer
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from pypdf import PdfReader
import pdfplumber

HERE=Path(__file__).resolve().parent
OUT=HERE/'delivery'
data=json.loads((OUT/'metrics.json').read_text(encoding='utf-8'))
pdfmetrics.registerFont(TTFont('Chinese','C:/Windows/Fonts/simhei.ttf'))
body=ParagraphStyle('body',fontName='Chinese',fontSize=9,leading=13,spaceAfter=5,alignment=TA_LEFT)
title=ParagraphStyle('title',parent=body,fontSize=15,leading=21,spaceAfter=8)
small=ParagraphStyle('small',parent=body,fontSize=8,leading=11,spaceAfter=3)
story=[]
def p(text,style=body): story.append(Paragraph(text,style))
def table(rows,widths):
    cells=[[Paragraph(str(v),small) for v in r] for r in rows]
    t=Table(cells,colWidths=widths,hAlign='LEFT')
    t.setStyle(TableStyle([
        ('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e9edf1')),
        ('TEXTCOLOR',(0,0),(-1,-1),colors.HexColor('#17212b')),
        ('GRID',(0,0),(-1,-1),.35,colors.HexColor('#c8d0d8')),
        ('VALIGN',(0,0),(-1,-1),'TOP'),
        ('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),
        ('TOPPADDING',(0,0),(-1,-1),3),('BOTTOMPADDING',(0,0),(-1,-1),2)]))
    story.append(t);story.append(Spacer(1,7))

p('LCM12864 雷达升级：本轮停止总结',title)
p('2026-10-16 | 第1项未达到门槛，已回退；最终保留 P5a-0 原版。未完成升级，未烧录。')
table([
    ['项目','状态 / 原因'],
    ['1 必需修复','回退：1109 LE，Fitter成功，setup 0.970 ns，比要求少0.030 ns。'],
    ['2 UFM背景','未进入RTL集成：第1项失败整轮停止。背景资产仅为未集成准备。'],
    ['3 反显 / 4 XOR / 5 数字 / 6 模式字 / 7 等级条','均未进入；没有改成OR、没有删原版功能。'],
], [195,326])
table([
    ['整机','LE / 寄存器','Fitter','setup / hold (ns)'],
    ['最终回退原版','1089 / 437','成功','3.786 / 1.078'],
    ['失败第1项候选','1109 / 455','成功','0.970 / 1.078'],
], [162,105,74,180])
p('各模块自身 LE（不重复计子树）')
table([['模块','原版','失败候选']]+[
    [label,a['le_self'],b['le_self']]
    for label,a,b in zip(
        ['wrapper','system','alarm_global','lcd_bus_phase','display门控','display core',
         'global timebase','draw控制','draw datapath','unified scan','reset','switch pair','ultrasonic'],
        data['retained']['modules'],data['failed_step1']['modules'])
], [351,85,85])
p('耗时：原版及候选受控测试最坏帧2.544780 ms，其中LCD读0.710400、写0.852480、状态机/算术/握手0.981900 ms；UFM读取0。相对连续模式60 ms的1°间隔余量57.455220 ms。UFM初始化不适用：未集成，原版仍清屏。')
p('验证：既有生产回归全部收尾，未见新功能回归；矩阵探针复现既有23.25 ms边界。新基本/连续各375请求逐字节参考通过；顶层基本快走merged=176、连续=0；pending仅执行最新请求、快照稳定。完整范围见 verification_results.md。')
p('例外与未约束：候选真实post-fit网表三组CDC断言全部PASS（raw仅meta、meta仅sync、≥2级）。候选输出仍58口/456路径，增减0；输入减少1口/140路径至0。回退原版恢复原有输入1口/140路径，不能冒充SW7已修复。')
p('交付：仅 p5a0_original_SW6_readback_1089LE.pof 为保留映像，SHA-256与原烧录文件一致；预览为回退版仿真，非实物。失败POF和补丁单独归档。不建立合格 p5-step1 标签。')
p('可选后续方向：将请求锁存与绘图启动分成两拍，缩短sample_event到position_count的6级路径；本轮未尝试，资源/时序收益未验证。')
p('烧录提醒：含UFM版本须在Programmer同时勾选CFM和UFM的Program/Configure，并对两区Verify。本轮原版UFM用量0，不包含新背景。',small)

target=OUT/'本轮停止总结.pdf'
SimpleDocTemplate(str(target),pagesize=(595.28,841.89),leftMargin=37,rightMargin=37,
                  topMargin=29,bottomMargin=26,title='P5 雷达升级停止总结',author='Codex').build(story)
assert len(PdfReader(target).pages)==1, 'Summary must remain one page'
with pdfplumber.open(target) as doc:
    doc.pages[0].to_image(resolution=120).save(str(OUT/'summary_render.png'))
print('PASS single-page PDF:',target)
