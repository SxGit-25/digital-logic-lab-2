`timescale 1ns/1ps
module tb_global_budget;
 reg clk=0,rst=1;always #10 clk=~clk;
 wire us,ms,q,frame_tick,blink,carrier;
 wire [14:0] frame_us;
 wire [1:0] color;
 reg [2:0] index=0;
 radar_global_timebase #(.CLK_HZ(1000000)) t(
 .clk(clk),.rst(rst),.tick_us(us),.tick_ms(ms),.tick_250us(q),
 .tick_20ms(frame_tick),.frame_us(frame_us),.display_index(index),
 .color_phase(color),.carrier_2khz(carrier),.blink_2hz(blink));
 wire [1:0] state;wire servo,fast,start,step;
 wire [11:0] angle;wire dir;
 radar_unified_scan #(.SELF_TEST_MS(2),.STANDBY_MS(2),.SLOT_MS(100),
 .SETTLE_MS(50),.FAST_STEP_US(16),.DISTANCE_IS_BCD(1),.USE_GLOBAL_TIMING(1)) s(
 .clk(clk),.rst(rst),.tick_us(us),.tick_ms(ms),.enable(1'b1),.continuous_mode(1'b0),
 .measure_busy(1'b0),.measure_done(1'b0),.distance_mm(12'b0),.distance_valid(1'b0),
 .distance_bcd(16'b0),.system_state(state),.servo(servo),.angle_bcd(angle),
 .direction_up(dir),.measure_start(start),.step_event(step),.fast_busy(fast),
 .global_frame_us(frame_us),.global_frame_tick(frame_tick));
 integer cycle=0,last_ms=0,last_q=0,last_frame=0,last_blink=0;
 integer nms=0,nq=0,nframe=0,nblink=0,nstart=0,steps=0;
 integer last_slot=0,fast_begin=0,fast_end=0,previous_angle=0,rise_cycle=0;
 integer expected_us,pulses=0,slot_seen=0;
 reg old_blink=1,old_servo=0,old_fast=0;
 function integer degrees;
 input [11:0] v;begin degrees=v[11:8]*100+v[7:4]*10+v[3:0];end
 endfunction
 always @(posedge clk) begin
  cycle=cycle+1;
  if(rst) index<=0;else if(q)index<=index+1'b1;
  if(!rst) begin
   if(ms)begin
    if(nms && cycle-last_ms!=1000)$fatal(1,"millisecond ratio");
    last_ms=cycle;nms=nms+1;
   end
   if(q)begin
    if(nq && cycle-last_q!=250)$fatal(1,"display tick ratio");
    last_q=cycle;nq=nq+1;
   end
   if(frame_tick)begin
    if(nframe && cycle-last_frame!=20000)$fatal(1,"PWM frame ratio");
    last_frame=cycle;nframe=nframe+1;
   end
   if(start)nstart=nstart+1;
   if(step)steps=steps+1;
  end
  #1;
  if(!rst) begin
   if(blink!=old_blink)begin
    if(nblink && cycle-last_blink!=250000)$fatal(1,"2Hz blink ratio");
    last_blink=cycle;nblink=nblink+1;old_blink=blink;
   end
   if(fast&&!old_fast)begin
    if(slot_seen && cycle-last_slot!=100000)$fatal(1,"basic slot changed");
    last_slot=cycle;fast_begin=cycle;slot_seen=slot_seen+1;
   end
   if(!fast&&old_fast)begin
    fast_end=cycle;
    if(cycle-fast_begin!=720)$fatal(1,"45 step fast walk !=720us");
   end
   old_fast=fast;
   if(servo&&!old_servo)begin rise_cycle=cycle;expected_us=(4500+degrees(angle)*100+4)/9;end
   if(!servo&&old_servo)begin
    if(cycle-rise_cycle!=expected_us)$fatal(1,"partial or wrong servo pulse got=%0d wanted=%0d",cycle-rise_cycle,expected_us);
    pulses=pulses+1;
   end
   old_servo=servo;
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=0;
  repeat(910000)@(negedge clk);
  if(nframe<45 || nms<909 || nblink!=3 || slot_seen!=9 || steps!=405 || pulses<43)
   $fatal(1,"coverage frames=%0d ms=%0d blink=%0d slots=%0d steps=%0d pulses=%0d",nframe,nms,nblink,slot_seen,steps,pulses);
  $display("PASS global timebase/scan ratios frames=%0d ms=%0d q=%0d blink=%0d slots=%0d fast_steps=%0d full_PWM=%0d samples=%0d",nframe,nms,nq,nblink,slot_seen,steps,pulses,nstart);
  $finish;
 end
endmodule
