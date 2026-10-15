`timescale 1ns/1ps
module tb_continuous_ctrl;
reg clk=0; always #5 clk=~clk;
reg rst=1,on=0,tick=1,busy=0,done=0,valid=1,dir=1;
reg[7:0] angle=0; reg[11:0] mm=100;
wire[1:0] state; wire start,cancel,en,cv; wire[2:0] idx,si,level,h0,h1,h2,h3,h4;
wire[7:0] sa; wire sd; wire[11:0] cd; wire[4:0] hv,hs;
radar_ctrl #(.SELF_TEST_MS(1),.STANDBY_MS(1),.SLOT_MS(8),.SETTLE_MS(1),.SUPPORT_CONTINUOUS(1),.CONTINUOUS_SAMPLE_MS(60)) dut(
.clk(clk),.rst(rst),.tick_ms(tick),.system_on(on),.angle_applied(1'b0),.measure_busy(busy),.measure_done(done),.distance_mm(mm),.distance_valid(valid),
.system_state(state),.servo_enable(en),.angle_idx(idx),.measure_start(start),.measure_cancel(cancel),.sample_idx(si),.current_distance(cd),.current_valid(cv),.current_level(level),
.hist_level0(h0),.hist_level1(h1),.hist_level2(h2),.hist_level3(h3),.hist_level4(h4),.hist_valid(hv),.hist_seen(hs),.continuous_mode(1'b1),.continuous_angle(angle),.continuous_direction_up(dir),.sample_angle(sa),.sample_direction_up(sd));
wire[31:0] digits; wire[23:0] colors; reg[11:0] live_bcd=0;
display_compose #(.SUPPORT_CONTINUOUS(1)) compose(.system_state(state),.blink_2hz(1'b1),.angle_idx(idx),.distance_bcd(16'h0100),.current_valid(cv),.hist_level0(h0),.hist_level1(h1),.hist_level2(h2),.hist_level3(h3),.hist_level4(h4),.hist_valid(hv),.hist_seen(hs),.row_idx(3'd4),.digit_codes(digits),.row_colors(colors),.continuous_mode(1'b1),.continuous_angle_bcd(live_bcd));
wire[15:0] leds; wire buzzer;
alarm_ctrl alarm(.clk(clk),.rst(rst),.tick_us(1'b1),.tick_ms(tick),.blink_2hz(1'b1),.system_state(state),.current_valid(cv),.current_level(level),.leds(leds),.buzzer(buzzer));
integer k,d,bin,lev,j,tests=0; reg[4:0] before_seen; reg[14:0] before_levels;
integer ticks=0,last_start=-1; reg old_start=0; reg saw_buzzer=0;
always @(posedge clk) begin
 if(rst || !on || state!=3) begin ticks=0; last_start=-1; old_start=0; end
 else begin
  if(tick) ticks=ticks+1;
  #1;
  if(start && !old_start) begin
   if(last_start>=0 && ((ticks-last_start)<60 || (ticks-last_start)%60!=0)) $fatal(1,"60-ms cadence %d",ticks-last_start);
   last_start=ticks;
  end
  old_start=start;
 end
 if(buzzer) saw_buzzer=1;
end
task cycle; begin @(posedge clk); #1; @(negedge clk); end endtask
function integer nearest; input integer a; begin nearest=a<23?0:a<68?1:a<113?2:a<158?3:4; end endfunction
initial begin
 repeat(3) cycle; rst=0; on=1;
 wait(state==3); @(negedge clk);
 busy=1;
 repeat(181) begin cycle; if(start) $fatal(1,"must skip busy sampling slots"); end
 busy=0;
 for(d=0;d<2;d=d+1) begin
  for(k=0;k<=180;k=k+1) begin
   angle=k; dir=d; live_bcd=((k/100)<<8)|(((k/10)%10)<<4)|(k%10);
   mm=(k%6==0)?199:(k%6==1)?200:(k%6==2)?400:(k%6==3)?600:(k%6==4)?800:3999;
   valid=(k%7)!=0; bin=nearest(k);
   while(!start) cycle;
   // The ultrasonic block consumes the registered start on this next edge.
   cycle;
   if(sa!==k || sd!==d || si!==bin) $fatal(1,"sample latch %d %d got %d %d %d",k,d,sa,sd,si);
   busy=1; tick=0;
   // Move well across another display bin while the measurement is pending.
   angle=(k+90)%181; live_bcd=12'h123;
   repeat(12) cycle;
   if(sa!==k || sd!==d || si!==bin) $fatal(1,"sample changed during echo");
   if(digits[31:20]!==12'h123) $fatal(1,"live display did not follow BCD");
   before_seen=hs; before_levels={h4,h3,h2,h1,h0};
   busy=0; done=1; cycle; done=0;
   lev=valid?(mm>=800?1:mm>=600?2:mm>=400?3:mm>=200?4:5):0;
   if(cd!==mm || cv!==valid || level!==lev || !hs[bin] || hv[bin]!==valid) $fatal(1,"distance/history binding %d %d",k,d);
   for(j=0;j<5;j=j+1) if(j!=bin && ({h4,h3,h2,h1,h0}>>(j*3)&7)!==(before_levels>>(j*3)&7)) $fatal(1,"history other bin changed");
   if(!valid && digits[15:0]!==16'haaaa) $fatal(1,"invalid must show dashes");
   if(valid && level==5) begin repeat(3) cycle; if(leds!==16'hffff) $fatal(1,"near alarm LEDs"); end
   tests=tests+1; tick=1; cycle;
  end
 end
 // Keep one near echo current long enough to observe the real carrier output.
 angle=90; dir=1; mm=100; valid=1;
 while(!start) cycle;
 cycle; busy=1; cycle; busy=0; done=1; cycle; done=0;
 repeat(300) cycle;
 if(!saw_buzzer) $fatal(1,"near alarm must sound carrier");
 on=0; cycle;
 if(hs!==0 || hv!==0 || cv!==0 || !cancel || en) $fatal(1,"off reset");
 $display("PASS controller: %d samples all 181 angles x 2 directions; nearest bins 23/68/113/158; crossed-angle echo binding; default 60-ms cadence and busy slot skipping; distance levels/invalid; live BCD; history isolation; alarm LEDs and buzzer carrier",tests); $finish;
end
initial begin #10000000; $fatal(1,"controller timeout"); end
endmodule
