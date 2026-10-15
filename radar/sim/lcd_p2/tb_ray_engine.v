`timescale 1ns/1ps
module tb_ray_engine;
 reg clk=0,rst=1,start=0;
 reg [7:0] angle=0;
 always #10 clk=~clk;
 wire [2:0] busy,done,pv;
 reg [2:0] ready=0;
 wire [5:0] step[0:2],y[0:2];
 wire [6:0] x[0:2];
 integer cycle=0,f,a,i;
 integer count[0:2];
 reg [2:0] finished=0,stalled=0;
 reg capture=0;
 reg [18:0] held[0:2];
 genvar g;
 generate for(g=0;g<3;g=g+1) begin: variants
  ray_engine #(.USE_UFM(g==1),.MIRROR_X(g==2)) dut(
   clk,rst,start,angle,busy[g],done[g],pv[g],ready[g],step[g],x[g],y[g]);
  always @(posedge clk) if(capture && !rst && dut.state==5 && step[g]<4)
   $fwrite(f,"%0d,%0d,%0d,%0d,%0d\n",g,a,step[g],x[g],y[g]);
 end endgenerate
 always @(negedge clk) begin
  cycle=cycle+1;
  ready[0]=(cycle%5)!=0;ready[1]=(cycle%7)>1;ready[2]=(cycle%3)!=0;
 end
 always @(posedge clk) if(!rst && capture) for(integer j=0;j<3;j=j+1) begin
  if(stalled[j] && {step[j],x[j],y[j]}!==held[j]) $fatal(1,"Unstable backpressure variant %0d",j);
  stalled[j]=pv[j] && !ready[j];held[j]={step[j],x[j],y[j]};
  if(pv[j] && ready[j]) begin
   if(step[j]!==count[j]+4 || y[j]<15 || x[j]<16 || x[j]>112) $fatal(1,"Ray step/bounds mismatch");
   $fwrite(f,"%0d,%0d,%0d,%0d,%0d\n",j,a,step[j],x[j],y[j]);count[j]=count[j]+1;
  end
  if(done[j]) finished[j]=1;
 end
 initial begin
  f=$fopen("ray_coordinates.csv","w");$fwrite(f,"variant,angle,step,x,y\n");
  for(i=0;i<3;i=i+1) count[i]=0;
  #80;@(negedge clk);rst=0;
  // Illegal requests must not enter busy or emit a completion.
  angle=181;start=1;repeat(4) @(negedge clk);start=0;
  if(busy || done || pv) $fatal(1,"Illegal angle accepted");
  // Reset aborts a ray even while the UFM serial lookup is outstanding.
  angle=35;start=1;@(negedge clk);start=0;repeat(12) @(negedge clk);
  rst=1;@(negedge clk);rst=0;
  if(busy || done || pv) $fatal(1,"Reset failed");
  capture=1;
  for(a=0;a<=180;a=a+1) begin
   for(i=0;i<3;i=i+1) count[i]=0;
   finished=0;stalled=0;angle=a;start=1;@(negedge clk);start=0;
   // Mutate angle during the ray: accepted inputs must be latched.
   angle=255;
   wait(&finished);@(negedge clk);
   for(i=0;i<3;i=i+1) if(count[i]!=45) $fatal(1,"Missing ray pixels");
  end
  $fclose(f);$display("PASS ray: 181 angles x 45 steps x case/UFM/mirror; backpressure, reset, illegal angles, latched input");$finish;
 end
 initial begin #100000000;$fatal(1,"Ray timeout");end
endmodule
