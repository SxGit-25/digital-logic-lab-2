`timescale 1ns/1ps
module tb_lcd_p1;
 reg clk=0,rst=1;
 always #10 clk=~clk;
 wire [7:0] dout[0:1],led[0:1];
 wire [1:0] oe,rd,wr,a0,res,cs,finished;
 wire [7:0] data0,data1;
 assign data0=dout[0];
 assign data1=oe[1] ? dout[1] : 8'bz;
 lcd_p1_core #(.RESET_CYCLES(10),.WAIT_CYCLES(20)) w(
 clk,rst,8'b0,dout[0],oe[0],rd[0],wr[0],a0[0],res[0],cs[0],led[0],finished[0]);
 lcd_p1_core #(.ENABLE_READBACK(1),.RESET_CYCLES(10),.WAIT_CYCLES(20)) r(
 clk,rst,data1,dout[1],oe[1],rd[1],wr[1],a0[1],res[1],cs[1],led[1],finished[1]);
 st7565_model mw(res[0],cs[0],rd[0],wr[0],a0[0],oe[0],data0);
 st7565_model mr(res[1],cs[1],rd[1],wr[1],a0[1],oe[1],data1);
 always @(posedge clk) if(!rst && (!oe[0] || !rd[0])) $fatal(1,"Write-only policy violated");
 reg [7:0] expected[0:1023];
 integer p,c,y,f;
 initial begin
  $readmemh("radar/lcd_p1/expected.hex",expected);
  #80;@(negedge clk);rst=0;
  wait(&finished); #200;
  if(led[1]!==8'hff || mr.reads!=2) $fatal(1,"Readback or dummy read failed");
  if(mw.reads!=0) $fatal(1,"Unexpected read");
  for(p=0;p<8;p=p+1) for(c=0;c<132;c=c+1) begin
   if(c<128) begin
    if(mw.ram[p*132+c]!==expected[p*128+c]) $fatal(1,"Pixel mismatch page %0d col %0d",p,c);
   end else if(mw.ram[p*132+c]!==0) $fatal(1,"Hidden columns not clear");
  end
  f=$fopen("radar/lcd_p1/p1_rings.pbm","w");
  $fwrite(f,"P1\n128 64\n");
  for(y=0;y<64;y=y+1) begin
   for(c=0;c<128;c=c+1) begin
    if(c!=0) $fwrite(f," ");
    $fwrite(f,"%0d",(mw.ram[(y/8)*132+c]>>(y%8))&1);
   end
   $fwrite(f,"\n");
  end
  $fclose(f);
  $display("PASS P1: both bus policies, clear 1056 bytes, ring image, dummy+FF readback, 30%% timing margin and turnaround");
  $finish;
 end
 initial begin #5000000;$fatal(1,"Timeout");end
endmodule
