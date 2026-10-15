`timescale 1ns/1ps
// Real-bus endpoint ghost reproduction. Run against baseline and fixed RTL.
module tb_lcd_endpoint #(parameter ORIGINAL=0);
 reg clk=0,rst=1,request=0,up=1,valid=1;
 reg [7:0] angle=170;
 reg [5:0] radius=20;
 always #10 clk=~clk;
 wire ready,done,initialized,oe,rd,wr,a0,res,cs;
 wire [7:0] dout,data;
 assign data=oe ? dout : 8'bz;
 lcd_p2_core #(.ENABLE_READBACK(1),.USE_UFM(1),.RESET_CYCLES(10),.WAIT_CYCLES(20)) dut(
  clk,rst,request,angle,up,radius,valid,ready,done,initialized,data,dout,oe,rd,wr,a0,res,cs);
 st7565_model model(res,cs,rd,wr,a0,oe,data);
 task snapshot;
  input [511:0] name;
  integer f,y,c;
  begin
   f=$fopen(name,"w");$fwrite(f,"P1\n128 64\n");
   for(y=0;y<64;y=y+1) begin
    for(c=0;c<128;c=c+1) $fwrite(f,"%0d ",(model.ram[(y/8)*132+c]>>(y%8))&1);
    $fwrite(f,"\n");
   end
   $fclose(f);
  end
 endtask
 integer a;
 initial begin
  #80;@(negedge clk);rst=0;wait(initialized && ready);@(negedge clk);
  for(a=170;a<=180;a=a+1) begin
   angle=a;up=a<180;radius=20;request=1;
   @(negedge clk);request=0;wait(done);@(negedge clk);
  end
  // Continue the actual one-degree reversal sequence, with no repeated 180.
  for(a=179;a>=174;a=a-1) begin
   angle=a;up=0;radius=35;request=1;
   @(negedge clk);request=0;wait(done);@(negedge clk);
  end
  // At 174 degrees r20=(44,61), r35=(29,59); neither coincides
  // with 180-degree r20=(44,63), which B legitimately redraws.
  if(!(model.ram[7*132+29]&8'h08)) $fatal(1,"174 degree new radius35 not drawn");
  if(ORIGINAL) begin
   if(!(model.ram[7*132+44]&8'h20)) $fatal(1,"Original endpoint two-target ghost not reproduced");
   snapshot("endpoint_turnaround_original.pbm");
  end else begin
   if(model.ram[7*132+44]&8'h20) $fatal(1,"Fixed endpoint retains old target");
   snapshot("endpoint_turnaround.pbm");
  end
  $display("PASS endpoint ORIGINAL=%0d: normal170..180..174; 174deg oldr20=%0d newr35=1",ORIGINAL,(model.ram[7*132+44]>>5)&1);$finish;
 end
 initial begin #30000000;$fatal(1,"Endpoint timeout");end
endmodule
