"""Include complete results and reproduction sources; hash every delivered file."""
import hashlib
import json
import shutil
import zipfile
from pathlib import Path

HERE=Path(__file__).resolve().parent
RADAR=HERE.parent
OUT=HERE/'results'
snapshot=OUT/'reproduction'
for source in list((RADAR/'rtl').glob('*.v'))+list((RADAR/'sim/lcd_p4').glob('*')):
    if source.is_file():
        dest=snapshot/source.relative_to(RADAR)
        dest.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source,dest)
for source in list(HERE.glob('*.ps1'))+list(HERE.glob('*.py'))+list(HERE.glob('*.q*'))+list(HERE.glob('*.sdc'))+list(HERE.glob('*.mif'))+list((RADAR/'lcd_p2').glob('lcd_sin*.mif'))+list((RADAR/'lcd_p2').glob('lcd_sin*.hex'))+[RADAR/'lcd_p2/generate_sin_lut.py',HERE/'radar_p4_variants.v',HERE/'README.md',RADAR/'sim/lcd/st7565_model.v',RADAR/'sim/tb_counter_equivalence.v',RADAR/'sim/run_tests.ps1',RADAR/'lcd_p2/timing_details.tcl',RADAR/'verification/资源优化与回归报告.md']:
    dest=snapshot/source.relative_to(RADAR)
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,dest)
# The original run_tests.ps1 compares against this historical source set.
for source in (RADAR/'verification/baseline/rtl').glob('*.v'):
    dest=snapshot/source.relative_to(RADAR);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
for source in (RADAR/'sim').glob('tb_*.v'):
    dest=snapshot/source.relative_to(RADAR);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest)
shutil.copy2(HERE/'README.md',OUT/'README.md')
manifest={p.relative_to(OUT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
          for p in sorted(OUT.rglob('*')) if p.is_file() and p.name!='manifest_sha256.json'}
(OUT/'manifest_sha256.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
archive=HERE/'results.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
    for p in sorted(OUT.rglob('*')):
        if p.is_file():z.write(p,'results/'+p.relative_to(OUT).as_posix())
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
print(f'{len(manifest)+1} files; {archive.stat().st_size} bytes; SHA256 {hashlib.sha256(archive.read_bytes()).hexdigest()}')
