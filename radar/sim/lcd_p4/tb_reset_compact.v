`timescale 1ns/1ps
module reset_case #(parameter N=16)(output reg complete=0);
 reg clk=0;
 wire rst;
 integer count=0;
 always #10 clk=~clk;
 reset_ctrl #(.RESET_CYCLES(N)) dut(clk,rst);
 initial begin
  #1;if(rst!==1) $fatal(1,"Reset missing at power up");
  repeat(N+2) begin
   @(posedge clk);count=count+1;#1;
   if(rst!==(count<N)) $fatal(1,"Reset duration N=%0d count=%0d",N,count);
  end
  complete=1;
 end
endmodule
module tb_reset_compact;
 wire [4:0] complete;
 reset_case #(1) r1(complete[0]);reset_case #(2) r2(complete[1]);
 reset_case #(16) r16(complete[2]);reset_case #(17) r17(complete[3]);
 reset_case #(257) r257(complete[4]);
 initial begin wait(&complete);$display("PASS reset power-up duration N=1/2/16/17/257");$finish;end
endmodule
