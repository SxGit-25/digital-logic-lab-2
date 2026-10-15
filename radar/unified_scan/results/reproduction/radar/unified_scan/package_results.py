"""Archive all result evidence plus reproducible sources, preserving byte hashes."""
import csv
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
RADAR = HERE.parent
RESULTS = HERE / "results"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def copy_files(source, target, recursive=False):
    paths = source.rglob("*") if recursive else source.iterdir()
    for p in paths:
        if p.is_file() and "__pycache__" not in p.parts and p.suffix != ".pyc":
            dest = target / p.relative_to(source)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dest)


def main():
    repro = RESULTS / "reproduction/radar"
    copy_files(RADAR / "rtl", repro / "rtl")
    copy_files(RADAR / "sim/unified_scan", repro / "sim/unified_scan")
    for p in (RADAR / "sim").iterdir():
        if p.is_file() and p.suffix in (".v", ".ps1"):
            target = repro / "sim" / p.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
    for relative in ("sim/lcd/st7565_model.v", "lcd_p2/timing_details.tcl"):
        dest = repro / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(RADAR / relative, dest)
    copy_files(RADAR / "verification/baseline/rtl", repro / "verification/baseline/rtl")
    for p in HERE.iterdir():
        if p.is_file() and p.suffix in (".v", ".ps1", ".py", ".tcl", ".qsf", ".qpf", ".sdc", ".md"):
            dest = repro / "unified_scan" / p.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, dest)
    for p in (RESULTS / "minsky").glob("*.py"):
        dest = repro / "unified_scan/results/minsky" / p.name
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, dest)
    delivery = RESULTS / "delivery"
    delivery.mkdir(exist_ok=True)
    shutil.copy2(RESULTS / "budget_final_index/bcd_safe/radar_unified_bcd_safe.pof", delivery / "radar_unified_safe_default.pof")
    (delivery / "README.md").write_text(
        "# 默认禁读的单一双模式映像\n\n"
        "radar_unified_safe_default.pof：ENABLE_READBACK=0，SW6运行时切换基本/连续。"
        "仅初始化/清屏；不是完整极坐标上板验收结果。未烧录。\n\n"
        "完整极坐标1089LE的回读参数映像仍在budget_final_index/bcd，"
        "仅供离线核对，不是电气安全批准。详见BUDGET_REPORT.md。\n", encoding="utf-8")

    checked = 0
    for manifest in RESULTS.rglob("source_sha256.csv"):
        source = manifest.parent / "source"
        if not source.is_dir():
            continue
        for row in csv.DictReader(manifest.open(encoding="utf-8-sig")):
            expected = row.get("SHA256", row.get("Hash"))
            assert expected and digest(source / row["File"]) == expected.upper(), str(manifest)
            checked += 1
    selected = RESULTS / "budget_final_index/bcd/source/rtl"
    live_count = 0
    for p in selected.glob("*.v"):
        assert digest(p) == digest(RADAR / "rtl" / p.name), f"Live source differs from selected fit: {p.name}"
        live_count += 1
    audit = dict(snapshot_files_verified=checked, selected_live_rtl_files_verified=live_count,
                 selected_build="budget_final_index/bcd", le=1089, registers=437,
                 source_default_readback=0, hardware_programmed=False)
    (RESULTS / "delivery_audit.json").write_text(json.dumps(audit, indent=2), encoding="utf-8")
    files = sorted(p for p in RESULTS.rglob("*") if p.is_file() and "__pycache__" not in p.parts
                   and p.suffix != ".pyc" and p.name != "manifest_sha256.csv")
    with (RESULTS / "manifest_sha256.csv").open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["File", "SHA256"])
        for p in files:
            writer.writerow([p.relative_to(RESULTS).as_posix(), digest(p)])
    files.append(RESULTS / "manifest_sha256.csv")
    archive = HERE / "results.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for p in files:
            z.write(p, "results/" + p.relative_to(RESULTS).as_posix())
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
    (HERE / "results.zip.sha256").write_text(digest(archive) + "  results.zip\n", encoding="ascii")
    print(json.dumps(dict(audit, archive_files=len(files), archive_bytes=archive.stat().st_size)))


if __name__ == "__main__":
    main()
