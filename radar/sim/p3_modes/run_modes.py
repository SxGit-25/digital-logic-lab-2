"""Run isolated P3 regressions against immutable commit 3231197."""
from pathlib import Path
import argparse, json, os, re, shutil, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[3]
RTL = ROOT / 'radar/rtl'
HERE = Path(__file__).resolve().parent

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--bin', type=Path, default=ROOT / '数电实验2/radar/sim/tools/iverilog/app/bin')
    p.add_argument('--stage', type=Path)
    p.add_argument('--test', action='append', help='Run only selected test module(s).')
    a = p.parse_args()
    stage = a.stage or Path(tempfile.mkdtemp(prefix='radar_p3_'))
    stage.mkdir(parents=True, exist_ok=True)
    result = ROOT / 'radar/p3_modes/results/simulation'
    result.mkdir(parents=True, exist_ok=True)
    for f in RTL.glob('*.v'): shutil.copy2(f, stage/f.name)
    for f in HERE.glob('tb_*.v'): shutil.copy2(f, stage/f.name)
    changed = ['servo_pwm','radar_ctrl','display_compose','radar_top']
    for name in changed:
        text = subprocess.check_output(['git','show',f'3231197:radar/rtl/{name}.v'],cwd=ROOT).decode()
        for old in changed: text = re.sub(r'\b'+old+r'\b','baseline_'+old,text)
        (stage/f'baseline_{name}.v').write_text(text,encoding='ascii')
    generate_equivalence(stage)
    rtl_names = ['reset_ctrl','timebase','switch_filter','servo_pwm','ultrasonic','radar_ctrl','bin12_to_bcd','display_compose','seg_scan','matrix_scan','alarm_ctrl','radar_top','radar_mode_top']
    sources = [f'{s}.v' for s in rtl_names] + [f'baseline_{s}.v' for s in changed]
    summary = {}
    for test in (a.test or ['tb_equivalence','tb_continuous_servo','tb_continuous_ctrl','tb_modes_integration']):
        command = [str(a.bin/'iverilog.exe'),'-g2005-sv','-s',test,'-o',test+'.vvp'] + sources + [test+'.v']
        compile_run = subprocess.run(command,cwd=stage,capture_output=True,text=True)
        (result/(test+'.compile.log')).write_text(compile_run.stdout+compile_run.stderr)
        if compile_run.returncode: raise RuntimeError(compile_run.stderr)
        run = subprocess.run([str(a.bin/'vvp.exe'),test+'.vvp'],cwd=stage,capture_output=True,text=True,timeout=240)
        log=run.stdout+run.stderr
        (result/(test+'.log')).write_text(log)
        print(log,flush=True)
        if run.returncode or 'PASS' not in log: raise RuntimeError(test+' failed')
        summary[test] = {'pass':True,'log':log.strip()}
    summary['baseline']='3231197'
    (result/'summary.json').write_text(json.dumps(summary,indent=2))

def generate_equivalence(stage):
    ports={'trig':1,'servo':1,'buzzer':1,'led':16,**{f'seg_{s}':1 for s in 'abcdefg'},'cat_n':8,'matrix_row_n':8,'matrix_col_r':8,'matrix_col_g':8}
    s='''`timescale 1ns/1ps
module tb_equivalence;
reg clk=0; always #5 clk=~clk;
reg sw7=0,echo=0;
integer i; integer rng=32'h1234567;
'''
    for prefix in ['old','basic','mode']:
        for name,width in ports.items(): s+=f'wire [{width-1}:0] {prefix}_{name};\n'
        module={'old':'baseline_radar_top','basic':'radar_top','mode':'radar_mode_top'}[prefix]
        s+=module+' #(.CLK_HZ(1000000),.SELF_TEST_MS(2),.STANDBY_MS(2),.SLOT_MS(40),.SETTLE_MS(1),.SWITCH_MS(1)) '+prefix+' (.clk(clk),.sw7(sw7),.echo(echo),'
        s+=','.join(f'.{name}({prefix}_{name})' for name in ports)
        s+=',.sw6(1\'b0)' if prefix=='mode' else ''
        s+=');\n'
    s+='initial begin\n for(i=0;i<500000;i=i+1) begin\n @(negedge clk); rng=rng*1664525+1013904223; if(i==100) sw7=1; if(i==300000) sw7=0; if(i==310000) sw7=1; echo=(rng & 511)==0 ? !echo:echo; @(posedge clk); #1;\n'
    for name in ports:
        s+=f'if(old_{name} !== basic_{name} || old_{name} !== mode_{name}) $fatal(1,"top baseline mismatch {name} cycle %d",i);\n'
    for sig in ['system_state','angle_idx','measure_start','measure_cancel','sample_idx','current_distance','current_valid','current_level','hist_seen','hist_valid','digit_codes','row_colors']:
        s+=f'if(old.{sig} !== basic.{sig} || old.{sig} !== mode.{sig}) $fatal(1,"internal baseline mismatch {sig} cycle %d",i);\n'
    s+='end $display("PASS top/composer/controller mode0 baseline equivalence: 500000 cycles, two tops, random echo, SW7 restart"); $finish; end\nendmodule\n'
    (stage/'tb_equivalence.v').write_text(s)

if __name__=='__main__': main()
