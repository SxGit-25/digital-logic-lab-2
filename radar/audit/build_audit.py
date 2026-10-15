"""Build a portable audit document from frozen build/programming evidence.

Read-only toward RTL and hardware. Uses only Python's standard library.
"""
import base64
import csv
import hashlib
import html
import json
import re
import shutil
import subprocess
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
OUT = HERE / "2026-10-15"
RESULTS = REPO / "radar/unified_scan/results"
BUILD = RESULTS / "budget_final_index/bcd"
PROGRAM = REPO / "radar/unified_scan/programming/20261015_readback"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def copy_file(src, relative):
    dest = OUT / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dest)


def facts_and_evidence():
    request = json.loads((PROGRAM / "request.json").read_text(encoding="utf-8-sig"))
    result = json.loads((PROGRAM / "result.json").read_text(encoding="utf-8-sig"))
    assert result["ExitCode"] == 0 and result["ProgramVerifySucceeded"]
    assert request["ElectricalSafetyConfirmedByUser"] and request["EnableReadback"] == 1
    image_hash = sha(BUILD / "radar_unified_bcd.pof")
    assert image_hash == request["SHA256"] == result["SHA256"]
    manifest = list(csv.DictReader((BUILD / "source_sha256.csv").open(encoding="utf-8-sig")))
    for row in manifest:
        assert sha(BUILD / "source" / row["File"]) == row["SHA256"].upper()
    rtl = list((BUILD / "source/rtl").glob("*.v"))
    for p in rtl:
        assert sha(p) == sha(REPO / "radar/rtl" / p.name), p.name
    for name in ("radar_unified_variants.v", "radar_unified_bcd.sdc"):
        assert sha(BUILD / "source/lcd_p4" / name) == sha(REPO / "radar/unified_scan" / name), name
    resources = list(csv.DictReader((RESULTS / "module_resources.csv").open(encoding="utf-8-sig")))
    resources = [r for r in resources if r["build"] == "budget_final_index/bcd"]
    assert sum(int(r["le_self"]) for r in resources) == 1089
    assert int(resources[0]["registers_including_children"]) == 437
    summary = (BUILD / "radar_unified_bcd.fit.summary").read_text()
    timing = (BUILD / "radar_unified_bcd.sta.summary").read_text()
    assert "1,089 / 1,270" in summary and "Successful" in summary
    assert "3.786" in timing and "1.078" in timing
    categories = [
        ("测距", 137, 67, 120), ("扫描+ctrl", 229, 100, 230),
        ("共享显示及门控", 151, 36, 195), ("报警", 15, 0, 50),
        ("LCD总线", 62, 29, 95), ("绘图含init", 395, 145, 210),
        ("顶层其余", 100, 60, 100),
    ]
    assert sum(c[1] for c in categories) == 1089
    assert sum(c[2] for c in categories) == 437
    for p in BUILD.rglob("*"):
        if p.is_file():
            copy_file(p, Path("evidence/selected_build") / p.relative_to(BUILD))
    for p in PROGRAM.glob("*"):
        if p.is_file():
            copy_file(p, Path("evidence/programming") / p.name)
    evidence = {
        "budget_draw_payload/budget_f15/simulation.log": "tests/draw/simulation.log",
        "budget_draw_payload/budget_f15/busy_walltime.csv": "tests/draw/busy_walltime.csv",
        "budget_top_index/simulation.log": "tests/top/simulation.log",
        "bcd_budget/ideal_error.json": "tests/ideal_error.json",
        "bcd_budget_compact/simulation.log": "tests/measurement/simulation.log",
        "minsky/schedule_search_report.json": "tests/schedule_search_report.json",
        "display_shared/simulation.log": "tests/display.log",
        "budget_units/tb_alarm_global.simulation.log": "tests/alarm.log",
        "budget_units/tb_global_budget.simulation.log": "tests/global.log",
        "budget_units/tb_switch_pair.simulation.log": "tests/switch.log",
        "budget_original_regression.log": "tests/original_regression.log",
        "scan_engine/final_index_quick.log": "tests/scan_quick.log",
        "scan_engine/settle_modes.log": "tests/settle_modes.log",
        "scan_engine/step5_notes.md": "tests/step5_notes.md",
        "matrix_bound/exhaustive.json": "tests/matrix_bound.json",
        "module_resources.csv": "module_resources.csv",
    }
    for source, dest in evidence.items():
        copy_file(RESULTS / source, Path("evidence") / dest)
    for name in ("tb_budget_top.v", "tb_budget_draw.v", "tb_ultrasonic_bcd_budget_compact.v"):
        copy_file(REPO / "radar/sim/unified_scan" / name, Path("evidence/tests") / name)
    for name in ("full_scan.png", "multiple_targets_turnaround.png"):
        copy_file(RESULTS / "budget_draw_payload/budget_f15" / name, Path("assets") / name)
    audit = {
        "audit_date_local": "2026-10-15", "timezone": "Asia/Shanghai",
        "source_commit": "a84e619", "programming_record_commit": "35c6e4d",
        "audit_start_head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
        "selected_project": "radar_unified_bcd", "top": "radar_unified_bcd_top",
        "device_target": "EPM1270T144C5", "clock_mhz": 50,
        "logic_elements": 1089, "registers": 437, "io_used": 75, "ufm_used": 0,
        "setup_slack_ns": 3.786, "hold_slack_ns": 1.078,
        "preferred_le_budget": 1143, "capacity_le": 1270,
        "source_snapshot_files_verified": len(manifest), "current_rtl_files_verified": len(rtl),
        "current_wrapper_and_sdc_verified": True,
        "pof_sha256": image_hash,
        "library_default_enable_readback": 0, "programmed_enable_readback": 1,
        "programmed_measurement_bcd": 1, "programmed_settle_from_pwm": 0,
        "electrical_safety_confirmation": "explicit user confirmation; no measurement attachment",
        "program_verify_succeeded": True,
        "program_completed_local": datetime.fromisoformat(result["CompletedUtc"].replace("Z", "+00:00")).astimezone(timezone(timedelta(hours=8))).isoformat(),
        "physical_function_acceptance_recorded": False,
        "unconstrained_inputs": 1, "unconstrained_outputs": 58,
        "categories": [dict(category=n, le=le, registers=r, budget=b, share_percent=round(le/1089*100, 2)) for n, le, r, b in categories],
        "remaining_items": ["basic fast-scan image completeness with drops", "measurement LE 137 > 120",
                            "drawing including init LE 395 > 210", "full board I/O constraints",
                            "physical functional acceptance", "direction mirror parameter", "drop counter external visibility"],
        "scope": "Read-only source/evidence audit; no compilation, programming or RTL modification in this audit task",
    }
    (OUT / "审计事实.json").write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")
    return categories


def svg_architecture():
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1120 690" role="img" aria-label="当前板上系统架构">',
             '<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto-start-reverse"><path d="M0,0 L8,4 L0,8 Z" fill="#51667e"/></marker></defs>',
             '<rect width="1120" height="690" rx="14" fill="#f4f7fb"/>',
             '<style>text{font-family:Microsoft YaHei,Arial,sans-serif;fill:#23344b}.t{font-size:16px;font-weight:600}.b{font-size:13px}.e{font-size:12px;fill:#52667e}</style>']

    def node(x, y, w, h, title, lines, color="#fff"):
        parts.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{color}" stroke="#c6d2e2"/>')
        parts.append(f'<text class="t" x="{x+15}" y="{y+27}">{html.escape(title)}</text>')
        for i, line in enumerate(lines):
            parts.append(f'<text class="b" x="{x+15}" y="{y+51+i*21}">{html.escape(line)}</text>')

    def edge(d, label=None, x=0, y=0, both=False):
        start = ' marker-start="url(#arrow)"' if both else ''
        parts.append(f'<path d="{d}" fill="none" stroke="#51667e" stroke-width="2"{start} marker-end="url(#arrow)"/>')
        if label:
            parts.append(f'<text class="e" text-anchor="middle" x="{x}" y="{y}">{html.escape(label)}</text>')

    node(30, 22, 280, 94, "唯一全局时基 · 67 LE", ["1µs / 1ms / 20ms / 250µs", "2Hz闪烁 / 2kHz载波 / 蜂鸣相位"])
    node(400, 22, 280, 94, "SW6 / SW7 · 9 LE", ["两级同步；共用20ms采样", "SW7原始关闭另走即时门控"])
    node(810, 22, 280, 94, "外部输入", ["50MHz · ECHO · SW6/SW7", "同一时钟域；外设使用使能节拍"])
    node(30, 190, 240, 114, "舵机输出", ["20ms帧，500～2500µs脉宽", "快走时保持旧完整目标", "方向/脉宽实际机械映射待验收"])
    node(350, 190, 340, 114, "统一扫描+ctrl · 229 LE", ["单套BCD角度 / 方向 / PWM / 调度", "基本：2s槽、45×16µs快走", "连续：60ms / 1°；锁存测量标签"], "#e8f0fd")
    node(810, 190, 280, 114, "超声 BCD 测距 · 137 LE", ["/294；工作与提交两份BCD", "20～4000mm；≤1200mm给LCD目标", "半径25mm分档、48饱和"])
    node(30, 405, 245, 124, "共享显示 · 151 LE", ["数码管角度/距离 + 五线RGB", "同一3位索引；2ms一帧", "历史仅5×level及seen", "含接口即时门控31 LE"])
    node(305, 405, 240, 124, "全局报警 · 15 LE", ["LED组 / 2Hz闪烁", "1/2/4/8Hz×50ms鸣叫", "2kHz载波；无局部分频"])
    node(585, 405, 280, 124, "绘图+init · 395 LE", ["Minsky / A擦除→B圈点及目标", "无队列，忙时丢弃并饱和计数", "控制283 + 数据通路112", "未达到210 LE分项预算"], "#fff0dc")
    node(895, 405, 195, 124, "LCD总线 · 62 LE", ["单相位计数器", "RD/WR/CS/OE寄存", "逐像素8事务RMW"])
    node(585, 575, 280, 80, "位串行数据通路", ["1位ALU + c/s/x/y，已含在395内"])
    node(895, 575, 195, 80, "外部ST7565R", ["1056字节RAM保存画面"])
    edge("M310 70 H350 V150 H430 V190", "节拍", 383, 142)
    edge("M540 116 V190", "模式/启停", 583, 156)
    edge("M950 116 V190", "同步ECHO", 998, 156)
    edge("M350 245 H270", "PWM", 309, 232)
    edge("M690 227 H810", "start / cancel", 750, 215)
    edge("M810 280 H755 V340 H520 V304", "done / BCD / 半径", 671, 330)
    edge("M420 304 V355 H150 V405", "角度/历史/提交BCD", 265, 346)
    edge("M500 304 V377 H425 V405", "当前等级", 460, 368)
    edge("M610 304 V365 H710 V405", "step / sample / 角度 / 半径", 807, 355)
    edge("M865 465 H895")
    edge("M725 529 V575", "微指令", 770, 555)
    edge("M992 529 V575", "8080 双向", 1042, 555, True)
    parts.append('<text class="e" x="30" y="620">50MHz clk与全局节拍连线从略；实际模块层级以Fitter原表为准。</text>')
    parts.append('<text class="e" x="30" y="643">其余100 LE：wrapper1 + system15 + 时基67 + reset8 + 开关9。</text>')
    parts.append('</svg>')
    return "".join(parts)


def svg_resources(categories):
    p = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 385" role="img" aria-label="各类LE占用">',
         '<rect width="1000" height="385" rx="12" fill="#f4f7fb"/>',
         '<style>text{font-family:Microsoft YaHei,Arial,sans-serif;font-size:15px;fill:#293a50}</style>']
    for i, (name, le, _, budget) in enumerate(sorted(categories, key=lambda c: c[1], reverse=True)):
        y = 34 + i*44
        fill = "#c17a32" if le > budget else "#446c9e"
        p.append(f'<text x="20" y="{y+7}">{html.escape(name)}</text>')
        p.append(f'<rect x="205" y="{y-12}" width="{le/395*540:.2f}" height="25" rx="3" fill="{fill}"/>')
        p.append(f'<text x="770" y="{y+7}">{le} LE / 预算{budget}</text>')
    p.append('<text x="20" y="365">各行不重复计子树：总计1089 LE；橙色表示该分项超预算，不代表整机超容量。</text></svg>')
    return "".join(p)


def inline(s):
    tokens = []

    def hold(m):
        tokens.append("<code>" + html.escape(m.group(1)) + "</code>")
        return f"\x00{len(tokens)-1}\x00"

    s = re.sub(r"`([^`]+)`", hold, s)
    s = html.escape(s)
    s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)
    for i, value in enumerate(tokens):
        s = s.replace(f"\x00{i}\x00", value)
    return s


def render(md, architecture, resources):
    lines = md.splitlines()
    body, toc = [], []
    section = i = 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        if line == "<!-- ARCHITECTURE -->":
            body.append('<figure class="diagram">'+architecture+'<figcaption><a href="assets/architecture.svg">打开架构图原图</a> · 资源为当前整机上下文，子树不重复计数</figcaption></figure>')
        elif line == "<!-- RESOURCES -->":
            body.append('<figure class="diagram">'+resources+'</figure>')
        elif line.startswith("```"):
            lang = line[3:]
            code = []
            i += 1
            while i < len(lines) and not lines[i].startswith("```"):
                code.append(lines[i])
                i += 1
            block = '<pre><code>'+html.escape("\n".join(code))+'</code></pre>'
            body.append('<details><summary>Mermaid架构源码</summary>'+block+'</details>' if lang == "mermaid" else block)
        elif line.startswith("#"):
            level = len(line)-len(line.lstrip("#"))
            title = line[level:].strip()
            if level == 2:
                section += 1
                anchor = f"sec-{section}"
                toc.append(f'<a href="#{anchor}">{html.escape(title)}</a>')
            else:
                anchor = f"heading-{i}"
            body.append(f'<h{level} id="{anchor}">{inline(title)}</h{level}>')
        elif line.startswith("|"):
            table = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [x.strip() for x in lines[i].strip().strip("|").split("|")]
                if not all(re.fullmatch(r":?-+:?", x) for x in cells):
                    table.append(cells)
                i += 1
            output = '<div class="table"><table><thead><tr>'+''.join('<th>'+inline(c)+'</th>' for c in table[0])+'</tr></thead><tbody>'
            output += ''.join('<tr>'+''.join('<td>'+inline(c)+'</td>' for c in row)+'</tr>' for row in table[1:])
            body.append(output+'</tbody></table></div>')
            continue
        elif line.startswith("!["):
            m = re.fullmatch(r"!\[([^]]*)\]\(([^)]+)\)", line)
            data = base64.b64encode((OUT / m.group(2)).read_bytes()).decode()
            body.append(f'<figure class="simulation"><img src="data:image/png;base64,{data}" alt="{html.escape(m.group(1))}"><figcaption>{html.escape(m.group(1))} · 仿真显存，非实屏照片</figcaption></figure>')
        elif line.startswith("- ") or re.match(r"\d+\. ", line):
            ordered = not line.startswith("- ")
            tag = "ol" if ordered else "ul"
            items = []
            while i < len(lines) and ((re.match(r"\d+\. ", lines[i]) is not None) if ordered else lines[i].startswith("- ")):
                text = re.sub(r"^(?:- |\d+\. )", "", lines[i])
                items.append('<li>'+inline(text)+'</li>')
                i += 1
            body.append(f'<{tag}>'+''.join(items)+f'</{tag}>')
            continue
        else:
            body.append('<p>'+inline(line)+'</p>')
        i += 1
    css = """
    *{box-sizing:border-box}html{scroll-behavior:auto}body{margin:0;background:#edf1f6;color:#202d3d;font-family:'Microsoft YaHei','Noto Sans CJK SC',Arial,sans-serif;line-height:1.8}
    .layout{max-width:1460px;margin:auto;display:grid;grid-template-columns:235px minmax(0,1fr);gap:28px;padding:26px}
    aside{position:sticky;top:24px;height:calc(100vh - 48px);overflow:auto;font-size:12px}aside b{display:block;font-size:16px;margin-bottom:14px}aside a{display:block;color:#465c77;text-decoration:none;padding:5px 8px;border-left:2px solid transparent}aside a:hover{background:#dfe8f4;border-color:#3c6da4}
    main{min-width:0;background:white;padding:38px 44px;border:1px solid #dce3ed;border-radius:12px;box-shadow:0 8px 28px #182d4b08}h1{font-size:29px;line-height:1.5;margin:0 0 18px}h2{font-size:23px;border-bottom:2px solid #e5ebf3;padding:18px 0 9px;margin-top:42px;scroll-margin-top:20px}h3{font-size:18px;margin:26px 0 9px}p,li{font-size:14px}a{color:#245f9a;text-decoration:none}a:hover{text-decoration:underline}strong{color:#132e50}
    code{font-family:Consolas,'Microsoft YaHei',monospace;font-size:.92em;background:#f0f3f7;border-radius:3px;padding:2px 4px;overflow-wrap:anywhere}pre{background:#15283e;color:#e0e8f2;border-radius:8px;padding:18px;overflow:auto;font-size:12px;line-height:1.65}pre code{padding:0;background:transparent;color:inherit;overflow-wrap:normal}
    .table{width:100%;overflow-x:auto;margin:18px 0}table{width:100%;border-collapse:collapse;font-size:12px;line-height:1.7}th{text-align:left;background:#eaf0f7;color:#203b5c;font-weight:600}td,th{padding:9px 10px;border:1px solid #dce4ee;vertical-align:top;overflow-wrap:anywhere}tr:nth-child(even) td{background:#f8fafc}td code{font-size:11px}
    figure{margin:22px 0}svg,img{display:block;max-width:100%;height:auto}figcaption{font-size:12px;color:#60738c;margin-top:8px}.simulation{border:1px solid #dde5ef;padding:14px;background:#fafbfd}.simulation img{width:768px;image-rendering:pixelated}.diagram svg{width:100%}details{font-size:12px;color:#51677f}
    .badge{font-size:12px;padding:8px 12px;background:#edf5ee;border-left:4px solid #547958;margin-bottom:22px}.badge span{display:block;color:#7b5630}
    @media(max-width:1000px){.layout{display:block;padding:12px}aside{position:relative;height:auto;max-height:240px;margin-bottom:18px}main{padding:20px}h1{font-size:24px}table{min-width:680px}}
    @media print{body{background:white}.layout{display:block;padding:0}aside{display:none}main{border:0;box-shadow:none;padding:0}h2,h3{break-after:avoid}table,figure{break-inside:avoid}pre{white-space:pre-wrap}details{display:none}.table{overflow:visible}a{color:inherit}}
    """
    return '<!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>简易雷达系统审计 · 1089 LE</title><style>'+css+'</style></head><body><div class="layout"><aside><b>系统审计 · 2026-10-15</b><a href="#">返回开头</a>'+''.join(toc)+'</aside><main><div class="badge">当前已编程校验：1089 LE / 437寄存器 / 50MHz<span>总资源达标；测距/绘图分项预算及实物完整功能仍有未完成项</span></div>'+''.join(body)+'</main></div></body></html>'


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    categories = facts_and_evidence()
    architecture, resources = svg_architecture(), svg_resources(categories)
    (OUT / "assets/architecture.svg").write_text(architecture, encoding="utf-8")
    (OUT / "assets/resources.svg").write_text(resources, encoding="utf-8")
    md = (OUT / "系统审计报告.md").read_text(encoding="utf-8")
    document = render(md, architecture, resources)
    assert document.count('<h2 ') == 16
    (OUT / "系统审计报告.html").write_text(document, encoding="utf-8")
    # The checksum manifest is generated below; validate its link afterwards.
    for _, url in re.findall(r"\[([^]]+)\]\(([^)]+)\)", md):
        if url != "文件校验清单.csv" and not url.startswith(("http:", "https:")):
            assert (OUT / url).is_file(), url
    paths = sorted(p for p in OUT.rglob("*") if p.is_file() and p.name not in ("文件校验清单.csv", "审计报告包.zip") and "qa" not in p.parts)
    with (OUT / "文件校验清单.csv").open("w", encoding="utf-8", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["File", "SHA256"])
        for p in paths:
            writer.writerow([p.relative_to(OUT).as_posix(), sha(p)])
    paths.append(OUT / "文件校验清单.csv")
    assert (OUT / "文件校验清单.csv").is_file()
    with zipfile.ZipFile(OUT / "审计报告包.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for p in paths:
            z.write(p, p.relative_to(OUT).as_posix())
    with zipfile.ZipFile(OUT / "审计报告包.zip") as z:
        assert z.testzip() is None
    print(json.dumps({"output": str(OUT), "evidence_and_report_files": len(paths), "html_bytes": len(document.encode()),
                      "zip_bytes": (OUT / "审计报告包.zip").stat().st_size, "rtl_unchanged": True}, ensure_ascii=False))


if __name__ == "__main__":
    main()
