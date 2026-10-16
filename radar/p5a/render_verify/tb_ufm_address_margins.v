`timescale 1ns/1ps
// Exhaust every free-running phase at request acceptance. No RTL changes.
module tb_ufm_address_margins;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,request=0,sequential=0;
 reg [8:0] address=0;
 wire busy,done;wire [15:0] value;
 p5_ufm_reader dut(.clk(clk),.rst(rst),.request(request),.sequential(sequential),
  .address(address),.busy(busy),.done(done),.value(value));
 reg [15:0] expected[0:511];
 realtime last_ardin=-1000,last_arshft=-1000,last_edge=-1000,accept_time=-1000;
 realtime min_setup=1e9,min_hold=1e9,min_first=1e9,delta;
 reg seen_edge=0,first_pending=0;
 integer checks=0,phase_mask=0,p,k,wait_cycles,a;
 always @(dut.addr_shift[8])begin
  if(!rst && seen_edge)begin
   delta=$realtime-last_edge;
   if(delta<160)$fatal(1,"ARDIN hold %0.1f ns <160",delta);
   if(delta<min_hold)min_hold=delta;
  end
  last_ardin=$realtime;
 end
 always @(dut.arshft)begin
  if(!rst && seen_edge)begin
   delta=$realtime-last_edge;
   if(delta<160)$fatal(1,"ARSHFT hold %0.1f ns <160",delta);
   if(delta<min_hold)min_hold=delta;
  end
  last_arshft=$realtime;
 end
 always @(posedge clk)if(!rst && request && !busy)begin
  accept_time=$realtime;first_pending=1;
  phase_mask=phase_mask|(1<<dut.phase);
 end
 always @(posedge dut.arclk)if(!rst)begin
  delta=$realtime-last_ardin;
  if(delta<40)$fatal(1,"ARDIN setup %0.1f ns <40",delta);
  if(delta<min_setup)min_setup=delta;
  delta=$realtime-last_arshft;
  if(delta<40)$fatal(1,"ARSHFT setup %0.1f ns <40",delta);
  if(delta<min_setup)min_setup=delta;
  if(first_pending)begin
   delta=$realtime-accept_time;
   if(delta<40)$fatal(1,"First ARCLK edge %0.1f ns <40",delta);
   if(delta<min_first)min_first=delta;
   first_pending=0;
  end
  last_edge=$realtime;seen_edge=1;
 end
 initial begin
  $readmemh("background.mem",expected);
  repeat(5)@(negedge clk);rst=0;
  for(k=0;k<2;k=k+1)for(p=0;p<16;p=p+1)begin
   while(busy || dut.phase!=p)@(negedge clk);
   if(k==0)begin sequential=0;a=(p&1)?9'h155:9'h0aa;end
   else begin sequential=1;a=(a+1)%512;end
   address=a;request=1;@(negedge clk);request=0;
   wait_cycles=0;
   while(!done && wait_cycles<600)begin @(negedge clk);wait_cycles=wait_cycles+1;end
   if(!done || value!==expected[a])$fatal(1,"Read mismatch phase%0d addr%0d",p,a);
   checks=checks+1;@(negedge clk);
  end
  if(phase_mask!=65535)$fatal(1,"Not all request phases covered: %h",phase_mask);
  $display("PASS address_margins checks=%0d phase_mask=%04x first_edge_min_ns=%0.1f setup_min_ns=%0.1f hold_min_ns=%0.1f",checks,phase_mask,min_first,min_setup,min_hold);
  $finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
