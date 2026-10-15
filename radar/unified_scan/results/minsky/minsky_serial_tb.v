`timescale 1ns/1ps
module minsky_serial_tb #(parameter FRACTION_BITS=17,ROT_SHIFT=8);
 reg clk=0,rst=1,request=0,advance=1;
 reg [2:0] command=0;
 always #10 clk=~clk;
 wire ready,done;
 wire signed [FRACTION_BITS+1:0] c,s;
 wire signed [FRACTION_BITS+6:0] x_acc,y_acc;
 wire signed [6:0] x_offset,y_offset;
 minsky_serial_datapath #(.FRACTION_BITS(FRACTION_BITS),.ROT_SHIFT(ROT_SHIFT)) dut(clk,rst,request,command,advance,ready,done,c,s,x_acc,y_acc,x_offset,y_offset);
 integer f,status,cmd,deposit,ci,si,xi,yi,ce,se,xe,ye,n=0,steps;
 reg [31:0] random_bits=32'hc312fa09;
 reg [4*FRACTION_BITS+17:0] held;
 task randomize;
  begin random_bits={random_bits[30:0],random_bits[31]^random_bits[21]^random_bits[1]^random_bits[0]};end
 endtask
 initial begin
  f=$fopen("serial_vectors.txt","r");
  if(!f)$fatal(1,"No stimuli");
  #80;@(negedge clk);rst=0;
  while(!$feof(f)) begin
   status=$fscanf(f,"%d %d %d %d %d %d %d %d %d %d\n",cmd,deposit,ci,si,xi,yi,ce,se,xe,ye);
   if(status!=10)$fatal(1,"Bad stimulus row %0d",n);
   @(negedge clk);
   if(!ready)$fatal(1,"Not ready before request");
   if(deposit) begin
    dut.registers.c=ci;dut.registers.s=si;
    dut.registers.x_acc=xi;dut.registers.y_acc=yi;
   end
   command=cmd;request=1;advance=1;steps=0;
   @(posedge clk);#1;
   @(negedge clk);request=0;
   while(!done) begin
    randomize();advance=random_bits[2:0]!=0;
    // Busy requests, including resets, must not alter the accepted command.
    request=random_bits[5:3]==0;command=random_bits[8:6];
    held={c,s,x_acc,y_acc};
    @(posedge clk);#1;
    if(!advance && {c,s,x_acc,y_acc}!==held)$fatal(1,"Stall changed data row%0d",n);
    if(advance)steps=steps+1;
    @(negedge clk);request=0;
   end
   if(!ready || $signed(c)!==ce || $signed(s)!==se || $signed(x_acc)!==xe || $signed(y_acc)!==ye)
    $fatal(1,"Result row=%0d cmd=%0d got=(%0d,%0d,%0d,%0d) expected=(%0d,%0d,%0d,%0d)",n,cmd,c,s,x_acc,y_acc,ce,se,xe,ye);
   if($signed(x_offset)!==(xe>>>FRACTION_BITS) || $signed(y_offset)!==(ye>>>FRACTION_BITS))$fatal(1,"Offset sign/round mismatch");
   if(steps!=(cmd>=6 ? 0 : cmd>=4 ? FRACTION_BITS+7 : FRACTION_BITS+2))$fatal(1,"Serial cycle count row%0d steps%0d",n,steps);
   n=n+1;
  end
  $display("PASS serial datapath %0d commands, independent Python bit-exact reference, random pauses/busy requests",n);
  $fclose(f);$finish;
 end
 initial begin #100000000;$fatal(1,"Timeout");end
endmodule
