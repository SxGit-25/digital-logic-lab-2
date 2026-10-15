`timescale 1ns/1ps
// Minimal collateral-erase reproduction, using the real bus/model and RTL.
module tb_lcd_alias;
 reg clk=0,rst=1,request=0,up=1,valid=1;
 reg [7:0] angle=172;
 reg [5:0] radius=26;
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
 initial begin
  #80;@(negedge clk);rst=0;wait(initialized && ready);@(negedge clk);
  request=1;@(negedge clk);request=0;wait(done);@(negedge clk);
  if(!(model.ram[7*132+38]&8'h08)) $fatal(1,"172 degree target was not drawn");
  snapshot("alias_before.pbm");
  angle=180;up=0;valid=0;request=1;@(negedge clk);request=0;wait(done);@(negedge clk);
  if(model.ram[7*132+38]&8'h08) $fatal(1,"Expected exact-algorithm alias not reproduced");
  snapshot("alias_after.pbm");
  $display("PASS reproduction: 172deg radius26 target (38,59) is cleared by k180 down / ahead170 step26; precise algorithm collateral erase confirmed");
  $finish;
 end
 initial begin #10000000;$fatal(1,"Alias reproduction timeout");end
endmodule
