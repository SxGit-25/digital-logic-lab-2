"""Passive VCD export from frozen RTL; no production RTL edits."""
from pathlib import Path
import concurrent.futures
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
ROOT=Path(__file__).resolve().parents[1]
BASE=Path(os.environ.get('RADAR_REPORT_BUNDLE',ROOT/'report_materials/radar_1270LE_20261022'))
OUT=BASE/'03_仿真波形与日志/新增波形'
FROZEN=BASE/'08_顶层代码与完整工程/完整工程/rtl'
IV=Path(os.environ['IVERILOG_BIN'])/'iverilog.exe' if 'IVERILOG_BIN' in os.environ else ROOT/'数电实验2/radar/sim/tools/iverilog/app/bin/iverilog.exe'
VVP=IV.with_name('vvp.exe')

MEASUREMENT=r'''`timescale 1ns/1ps
module tb_report_measure;
 reg clk=0,rst=1,start=0,cancel=0,echo=0;
 always #10 clk=~clk;
 integer usphase=0,msphase=0;
 wire tick_us=usphase==49,tick_ms=msphase==49999;
 always @(posedge clk)begin
  if(rst)begin usphase<=0;msphase<=0;end
  else begin usphase<=tick_us?0:usphase+1;msphase<=tick_ms?0:msphase+1;end
 end
 wire trig,busy,done,valid,rv; wire [15:0] bcd;wire [2:0] level;wire [5:0] radius;
 ultrasonic_bcd_budget_compact dut(.clk(clk),.rst(rst),.tick_us(tick_us),.tick_ms(tick_ms),
 .measure_start(start),.cancel(cancel),.echo_async(echo),.trig(trig),.measure_busy(busy),
 .measure_done(done),.distance_bcd(bcd),.distance_valid(valid),.distance_level(level),
 .radius(radius),.radius_valid(rv));
 integer n,expected,samples=0;
 initial begin
  $dumpfile("trace.vcd");$dumpvars(0,start,echo,trig,busy,done,valid,bcd,level,radius,rv);
 end
 task launch;begin
  @(negedge clk);start=1;@(negedge clk);start=0;wait(trig);wait(!trig);
  repeat(7)@(negedge clk);
 end endtask
 task pulse;input integer mm;begin
  launch;echo=1;repeat(mm*294+1)@(negedge clk);echo=0;
  wait(done);#1;n=bcd[15:12]*1000+bcd[11:8]*100+bcd[7:4]*10+bcd[3:0];
  expected=mm>=800?1:mm>=600?2:mm>=400?3:mm>=200?4:5;
  if(n!=mm || !valid || level!=expected)$fatal(1,"measurement mismatch mm=%0d got=%0d",mm,n);
  $display("MEASURE time_ps=%0t mm=%0d bcd=%04x level=%0d radius=%0d",$time,n,bcd,level,radius);
  // Keep the valid result visible for 200us before the next independent test.
  samples=samples+1;repeat(10000)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=0;
  pulse(20);pulse(199);pulse(200);pulse(800);pulse(1200);pulse(4000);
  launch;wait(done);#1;if(valid || rv)$fatal(1,"timeout validity");
  $display("PASS report_measure six valid distances and no-echo timeout; physical clock 50MHz");$finish;
 end
 initial begin #150000000;$fatal(1,"measurement timeout");end
endmodule
'''

SCAN=r'''`timescale 1ns/1ps
// A waveform collection bench: real 50MHz clock; shortened SELF/STANDBY/basic
// SLOT/SETTLE explicitly declared. Continuous step remains the real 60ms.
// Sensor completion is a controller-level response model, not an ECHO model.
module tb_report_scan #(parameter MODE=0);
 reg clk=0,rst=1,enable=0;always #10 clk=~clk;
 integer usphase=0,msphase=0;
 wire tick_us=usphase==49,tick_ms=msphase==49999;
 always @(posedge clk)begin
  if(rst)begin usphase<=0;msphase<=0;end
  else begin usphase<=tick_us?0:usphase+1;msphase<=tick_ms?0:msphase+1;end
 end
 wire [1:0] state;wire servo,measure_start,measure_cancel,step_event,sample_event,fast;
 wire [11:0] angle,sample_angle;wire up,current_valid;wire [2:0] level;
 reg busy=0,done=0;integer response=0,samples=0;
 radar_unified_scan #(.SELF_TEST_MS(2),.STANDBY_MS(2),.SLOT_MS(20),.SETTLE_MS(3),
 .CONTINUOUS_STEP_MS(60),.FAST_STEP_US(16),.CONTINUOUS_DEGREE_STEP(1)) dut(
 .clk(clk),.rst(rst),.enable(enable),.continuous_mode(MODE!=0),.tick_us(tick_us),.tick_ms(tick_ms),
 .measure_busy(busy),.measure_done(done),.distance_mm(12'd600),.distance_valid(1'b1),
 .system_state(state),.servo(servo),.angle_bcd(angle),.direction_up(up),
 .measure_start(measure_start),.measure_cancel(measure_cancel),.sample_angle_bcd(sample_angle),
 .current_valid(current_valid),.current_level(level),.step_event(step_event),
 .sample_event(sample_event),.fast_busy(fast));
 always @(posedge clk)begin
  done<=0;
  if(rst || measure_cancel)begin busy<=0;response<=0;end
  else if(measure_start)begin busy<=1;response<=5;end
  else if(tick_us && response>0)begin
   response<=response-1;if(response==1)begin busy<=0;done<=1;end
  end
  if(sample_event)samples<=samples+1;
 end
 initial begin
  $dumpfile("trace.vcd");$dumpvars(0,enable,state,servo,angle,up,measure_start,sample_event,sample_angle,fast,current_valid,level);
  repeat(5)@(negedge clk);rst=0;enable=1;
  #195000000;
  if(state!=3 || samples<3)$fatal(1,"scan did not run");
  $display("PASS report_scan mode=%0d samples=%0d angle_bcd=%03x; clk50MHz SELF2ms STANDBY2ms basicSLOT20ms SETTLE3ms continuousSTEP60ms",MODE,samples,angle);
  $finish;
 end
endmodule
'''

BEAM_PROBE=r'''
 wire [2:0] report_task=!initialized?3'd5:dut.state==0?3'd0:dut.beam_task?(dut.flush_left[0]?3'd4:3'd1):dut.erase?3'd2:3'd3;
 initial begin
  $dumpfile("trace.vcd");
  $dumpvars(0,initialized,request,angle_bcd,radius,done,dut.beam_valid,dut.beam_angle,report_task,stop_request,quiescent);
 end
'''

ALARM_PROBE=r'''
 reg [7:0] report_command=0;
 always @(posedge clk)if(!rst && initialized && lcd.pending && lcd.remaining==0 &&
 !lcd.held_read && !lcd.held_data && (lcd.held_byte==8'ha6 || lcd.held_byte==8'ha7))
  report_command<=lcd.held_byte;
 initial begin
  $dumpfile("trace.vcd");
  $dumpvars(0,alarm_active,inverse_phase,current_valid,current_level,dut.last_inverse,report_command,command_count);
 end
'''


def run(name, top, tb, options=()):
    dest=OUT/name
    dest.mkdir(parents=True,exist_ok=True)
    stage=Path(tempfile.mkdtemp(prefix='report_wave_'))
    for f in FROZEN.glob('*.v'):shutil.copy2(f,stage/f.name)
    shutil.copy2(BASE/'02_系统设计/UFM背景/background.mem',stage/'background.mem')
    (stage/'input_tb.v').write_text(tb,encoding='ascii')
    if name=='beam':
        for f in ['lcd_ram_bfm.v','reference.py']:
            shutil.copy2(BASE/'03_仿真波形与日志/波形复现输入'/f,stage/f)
        subprocess.run([sys.executable,str(stage/'reference.py'),'prepare',str(stage),'--background',
                        str(BASE/'02_系统设计/UFM背景/background_bytes.mem'),'--mode','basic','--beam','--smoke'],check=True,capture_output=True)
    if name=='alarm':
        shutil.copy2(BASE/'03_仿真波形与日志/波形复现输入/lcd_ram_bfm.v',stage/'lcd_ram_bfm.v')
        import importlib.util
        spec=importlib.util.spec_from_file_location('report_reference',BASE/'03_仿真波形与日志/波形复现输入/reference.py')
        ref=importlib.util.module_from_spec(spec);spec.loader.exec_module(ref)
        model=ref.Reference(ref.load_background(BASE/'02_系统设计/UFM背景/background_bytes.mem'),continuous=True,beam=True)
        data=bytearray()
        for a,r in [(90,24),(91,31)]:model.request(a,True,r,True);data.extend(model.ram)
        (stage/'alarm_expected.mem').write_text(''.join(f'{v:02x}\n' for v in data))
    sources=sorted(f.name for f in stage.glob('*.v'))
    command=[str(IV),'-g2005-sv','-s',top,*options,'-o','test.vvp',*sources]
    env=dict(os.environ,TEMP=str(stage),TMP=str(stage))
    with (dest/'compile.log').open('w') as log:
        result=subprocess.run(command,cwd=stage,env=env,stdout=log,stderr=subprocess.STDOUT)
    assert result.returncode==0, (name,'compile')
    with (dest/'simulation.log').open('w') as log:
        result=subprocess.run([str(VVP),'test.vvp'],cwd=stage,env=env,stdout=log,stderr=subprocess.STDOUT)
    assert result.returncode==0 and 'PASS' in (dest/'simulation.log').read_text(),(name,'simulation')
    keep={'.vcd','.vh','.json','.csv'}
    for f in stage.iterdir():
        if f.suffix in keep or f.name in ['input_tb.v','requests.mem','fixture.vh']:
            shutil.copy2(f,dest/f.name)
    if name=='beam':
        checked=subprocess.run([sys.executable,str(stage/'reference.py'),'compare',str(stage)],capture_output=True,text=True)
        (dest/'comparison.log').write_text(checked.stdout+checked.stderr)
        assert checked.returncode==0
        shutil.copy2(stage/'final_preview.png',dest/'final_preview.png')
    hashes={f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in stage.glob('*.v')}
    (dest/'source_hashes.json').write_text(json.dumps(hashes,indent=2))
    (dest/'run.json').write_text(json.dumps(dict(name=name,top=top,options=options,stage=str(stage),
          compile_command=command,rtl_source='08_顶层代码与完整工程/完整工程/rtl',
          testbench='input_tb.v',pass_=True),indent=2))
    return dict(name=name,pass_=True,vcd_bytes=(dest/'trace.vcd').stat().st_size)


def main():
    original=(BASE/'03_仿真波形与日志/波形复现输入/tb_render.v').read_text()
    alarm=(BASE/'03_仿真波形与日志/波形复现输入/tb_alarm_inverse.v').read_text()
    cases=[('measurement','tb_report_measure',MEASUREMENT,()),
           ('scan_basic','tb_report_scan',SCAN,('-Ptb_report_scan.MODE=0',)),
           ('scan_continuous','tb_report_scan',SCAN,('-Ptb_report_scan.MODE=1',)),
           ('beam','tb_render',original.rsplit('endmodule',1)[0]+BEAM_PROBE+'\nendmodule\n',('-Ptb_render.REAL_TIMING=1',)),
           ('alarm','tb_alarm_inverse',alarm.rsplit('endmodule',1)[0]+ALARM_PROBE+'\nendmodule\n',())]
    OUT.mkdir(parents=True,exist_ok=True)
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures=[pool.submit(run,*c) for c in cases]
        for future in concurrent.futures.as_completed(futures):
            result=future.result();results.append(result);print(json.dumps(result),flush=True)
    (OUT/'status.json').write_text(json.dumps(results,indent=2))


if __name__=='__main__':main()
