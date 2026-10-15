`timescale 1ns/1ps
`include "scenario_counts.vh"
module tb_lcd_p2 #(parameter USE_UFM=0);
 reg clk=0,rst=1,request=0;
 reg [7:0] angle=0;
 reg direction_up=1,radius_valid=1;
 reg [5:0] radius=0;
 always #10 clk=~clk;
 wire ready,done,initialized,oe,rd,wr,a0,res,cs;
 wire [7:0] dout,data;
 assign data=oe ? dout : 8'bz;
 lcd_p2_core #(.ENABLE_READBACK(1),.USE_UFM(USE_UFM),.RESET_CYCLES(10),.WAIT_CYCLES(20)) dut(
  clk,rst,request,angle,direction_up,radius,radius_valid,ready,done,initialized,
  data,dout,oe,rd,wr,a0,res,cs);
 st7565_model model(res,cs,rd,wr,a0,oe,data);
 wire safe_ready,safe_done,safe_init,safe_oe,safe_rd,safe_wr,safe_a0,safe_res,safe_cs;
 wire [7:0] safe_dout;
 lcd_p2_core #(.RESET_CYCLES(10),.WAIT_CYCLES(20)) safe(
  clk,rst,request,angle,direction_up,radius,radius_valid,safe_ready,safe_done,safe_init,
  8'hff,safe_dout,safe_oe,safe_rd,safe_wr,safe_a0,safe_res,safe_cs);
 always @(posedge clk) if(!rst && (!safe_oe || !safe_rd || safe_ready || safe_done))
  $fatal(1,"Default readback safety policy violated");
 reg [23:0] scenarios[0:`SCENARIOS-1];
 reg [18:0] pixels[0:`PIXELS-1];
 reg [7:0] expected[0:1055];
 integer scenario,ptr=0,tx=0,nops,oldptr,j,index,commands=0;
 reg [7:0] wanted;
 reg want_read,want_data;
 wire [18:0] pixel=pixels[ptr];
 wire [2:0] ep= pixel[17:15];
 wire [6:0] ec= pixel[14:8];
 wire [7:0] em=pixel[7:0];
 // Compare accepted operations before lcd_bus serializes them. These values
 // come from a separate software command stream, never from DUT ray state.
 always @(posedge clk) if(!rst && initialized && dut.draw_request && dut.bus_ready) begin
  if(ptr>=`PIXELS) $fatal(1,"Extra pixel transaction");
  index=ep*132+ec;want_read=(tx==3 || tx==4);want_data=want_read || tx==7;
  case(tx)
   0:wanted=8'hb0|ep;
   1,5:wanted=8'h10|(ec>>4);
   2,6:wanted=ec&15;
   7:wanted=pixel[18] ? expected[index]&~em : expected[index]|em;
   default:wanted=0;
  endcase
  if(dut.draw_read_op!==want_read || dut.draw_data_op!==want_data)
   $fatal(1,"RMW operation/order mismatch scenario=%0d pixel=%0d tx=%0d",scenario,ptr,tx);
  if(!want_read && dut.draw_data!==wanted)
   $fatal(1,"RMW address/data mismatch scenario=%0d pixel=%0d tx=%0d got=%h expected=%h",scenario,ptr,tx,dut.draw_data,wanted);
  if(tx==7) begin expected[index]=wanted;ptr=ptr+1;tx=0;end else tx=tx+1;
  commands=commands+1;
 end
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
  $readmemh("scenario.hex",scenarios);$readmemh("pixels.hex",pixels);
  for(j=0;j<1056;j=j+1) expected[j]=0;
  #80;@(negedge clk);rst=0;
  wait(initialized && safe_init);@(negedge clk);
  // Invalid update must be ignored, then a valid update must still work.
  angle=181;request=1;@(negedge clk);request=0;repeat(8) @(negedge clk);
  if(!ready || done) $fatal(1,"Controller accepted illegal angle");
  for(scenario=0;scenario<`SCENARIOS;scenario=scenario+1) begin
   wait(ready);@(negedge clk);
   angle=scenarios[scenario][23:16];direction_up=scenarios[scenario][15];
   radius=scenarios[scenario][14:9];radius_valid=scenarios[scenario][8];
   nops=scenarios[scenario][7:0];oldptr=ptr;request=1;
   @(negedge clk);request=0;
   // Later external changes and spurious requests while busy cannot alter
   // this update's latched angle, direction, radius, or validity.
   angle=255;direction_up=~direction_up;radius=63;radius_valid=0;
   repeat(4) @(negedge clk);request=1;@(negedge clk);request=0;
   wait(done);@(negedge clk);
   if(ptr-oldptr!=nops || tx!=0) $fatal(1,"Missing A/B pixel operations");
   for(j=0;j<1056;j=j+1) if(model.ram[j]!==expected[j])
    $fatal(1,"RAM/neighbor corruption scenario=%0d addr=%0d got=%h want=%h",scenario,j,model.ram[j],expected[j]);
   if(scenario==180) snapshot("outbound.pbm");
   if(scenario==360) snapshot("full_scan.pbm");
  end
  snapshot("multiple_targets_turnaround.pbm");
  if(ptr!=`PIXELS || model.reads!=`PIXELS*2 || commands!=`PIXELS*8)
   $fatal(1,"Incorrect transaction totals");
  $display("PASS LCD P2: %0d updates, %0d RMW pixels, %0d bus transactions; full RAM checked per update; default safety checked",`SCENARIOS,ptr,commands);
  $finish;
 end
 initial begin #1000000000;$fatal(1,"LCD P2 timeout");end
endmodule
