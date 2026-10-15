`timescale 1ns/1ps
module coefficients_variant #(parameter F=8, U=0, SERIAL_ACCUMULATE=0)(output reg finished=0);
 reg clk=0,rst=1,request=0,start=0;
 always #10 clk=~clk;
 reg [6:0] address=0;
 wire lut_done; wire [F:0] value;
 lcd_sin_lut #(.USE_UFM(U),.FRACTION_BITS(F)) lut(clk,rst,request,address,lut_done,value);
 reg [7:0] angle=0;
 wire busy,done,pixel_valid; wire [5:0] step,y;wire [6:0] x;
 reg pixel_ready=0;integer cycle=0;
 reg stalled=0;reg [18:0] held;
 always @(negedge clk) begin cycle=cycle+1;pixel_ready=(cycle%7)>1;end
 always @(posedge clk) begin
  if(rst) stalled<=0;
  else begin
   if(stalled && {step,x,y}!==held) $fatal(1,"Backpressure stability F=%0d U=%0d",F,U);
   stalled<=pixel_valid && !pixel_ready;held<={step,x,y};
  end
 end
 ray_engine #(.USE_UFM(U),.FRACTION_BITS(F),.SERIAL_ACCUMULATE(SERIAL_ACCUMULATE)) ray(clk,rst,start,angle,busy,done,pixel_valid,pixel_ready,step,x,y);
 integer a,expected,file_handle,observed;
 initial begin
  file_handle=$fopen($sformatf("coefficients_q%0d_u%0d.csv",F,U),"w");
  $fwrite(file_handle,"angle,step,x,y\n");
  #80; @(negedge clk);rst=0;
  for(a=0;a<=90;a=a+1) begin
   address=a;request=1;@(negedge clk);request=0;
   wait(lut_done);#1;
   expected=$rtoi($sin(a*3.141592653589793/180.0)*(1<<F)+0.5);
   if(value!==expected) $fatal(1,"LUT F=%0d U=%0d a=%0d got=%0d expected=%0d",F,U,a,value,expected);
   @(negedge clk);
  end
  for(a=0;a<=180;a=a+1) begin
   observed=0;angle=a;start=1;@(negedge clk);start=0;
   while(!done) begin
    #1;
    if(ray.state==5 && (step<6 || pixel_ready)) begin
     if(step!==observed || pixel_valid!==(step>=6)) $fatal(1,"step/valid F=%0d U=%0d",F,U);
     $fwrite(file_handle,"%0d,%0d,%0d,%0d\n",a,step,x,y);observed=observed+1;
    end
    @(negedge clk);
   end
   if(observed!=49) $fatal(1,"Missing ray steps F=%0d U=%0d count=%0d",F,U,observed);
   @(negedge clk);
  end
  $fclose(file_handle);$display("PASS F=%0d U=%0d LUT91/rays181x49",F,U);finished=1;
 end
endmodule
module coefficients_tb #(parameter SERIAL_ACCUMULATE=0);
 wire [5:0] finished;
 genvar i;
 generate for(i=0;i<6;i=i+1) begin:g
  coefficients_variant #(.F(8-i/2),.U(i%2),.SERIAL_ACCUMULATE(SERIAL_ACCUMULATE)) v(finished[i]);
 end endgenerate
 initial begin wait(&finished);$display("PASS all coefficient variants");$finish;end
 initial begin #100000000;$fatal(1,"Timeout");end
endmodule
