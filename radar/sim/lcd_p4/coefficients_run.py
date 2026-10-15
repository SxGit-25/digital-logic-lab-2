"""Run six RTL variants and independent geometry checks; preserve review evidence."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

HERE=Path(__file__).resolve().parent
RADAR=HERE.parents[1]
ROOT=RADAR.parent


def run():
    parser=argparse.ArgumentParser()
    parser.add_argument('--iverilog-bin',type=Path)
    parser.add_argument('--output',type=Path,default=RADAR/'lcd_p4/results/coefficients')
    args=parser.parse_args()
    candidates=[ROOT/'radar/sim/tools/iverilog/app/bin',ROOT/ROOT.name/'radar/sim/tools/iverilog/app/bin']
    binary=args.iverilog_bin or next((p for p in candidates if (p/'iverilog.exe').exists()),None)
    if binary is None:parser.error('Provide --iverilog-bin containing iverilog.exe and vvp.exe')
    stage=Path(tempfile.mkdtemp(prefix='lcd_p4_coefficients_'))
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    for source in (RADAR/'rtl/lcd_sin_lut.v',RADAR/'rtl/ray_engine.v',HERE/'coefficients_tb.v'):
        shutil.copy2(source,stage/source.name)
    commands=[
        [str(binary/'iverilog.exe'),'-g2012','-s','coefficients_tb','-o','coefficients.vvp','lcd_sin_lut.v','ray_engine.v','coefficients_tb.v'],
        [str(binary/'vvp.exe'),'coefficients.vvp'],
        [sys.executable,str(HERE/'coefficients_geometry.py'),str(stage)],
    ]
    with (output/'coefficients_run.log').open('w',encoding='utf-8') as log:
        for command in commands:
            result=subprocess.run(command,cwd=stage,capture_output=True,text=True,timeout=90)
            log.write('COMMAND: '+subprocess.list2cmdline(command)+'\n'+result.stdout+result.stderr+'\n')
            log.flush()
            print(result.stdout,end='');print(result.stderr,end='',file=sys.stderr)
            if result.returncode:raise SystemExit(result.returncode)
    for source in stage.glob('coefficients_*.csv'):
        shutil.copy2(source,output/source.name)
    shutil.copy2(stage/'coefficients_report.json',output/'coefficients_report.json')
    print('Evidence:',output)
    print('ASCII verification stage:',stage)

if __name__=='__main__':run()
