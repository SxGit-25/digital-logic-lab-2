`timescale 1ns/1ps
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
