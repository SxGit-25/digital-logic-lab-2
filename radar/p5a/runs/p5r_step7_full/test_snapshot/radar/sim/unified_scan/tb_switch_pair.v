`timescale 1ns/1ps
module tb_switch_pair;
 reg clk=0,rst=1,tick=0,a=0,b=0;always #10 clk=~clk;
 wire x,y;
 switch_pair_sampled s(clk,rst,tick,a,b,x,y,);
 task sample;
 begin @(negedge clk);tick=1;@(negedge clk);tick=0;#1;end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=0;
  a=1;b=1;repeat(3)@(negedge clk);
  sample;if(x||y)$fatal(1,"accepted only one sample");
  sample;if(!x||!y)$fatal(1,"two equal samples rejected");
  a=0;repeat(3)@(negedge clk);sample;if(!x||!y)$fatal(1,"bounce accepted");
  a=1;repeat(3)@(negedge clk);sample;if(!x||!y)$fatal(1,"restored sample");
  a=0;b=0;repeat(3)@(negedge clk);sample;if(!x||!y)$fatal(1,"fall accepted too early");
  sample;if(x||y)$fatal(1,"stable falling pair not accepted");
  $display("PASS paired switch sampling: shared tick, two stable samples, bounce and independent bits");$finish;
 end
endmodule
