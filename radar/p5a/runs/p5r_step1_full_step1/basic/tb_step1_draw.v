`timescale 1ns/1ps
`include "draw_counts.vh"
module tb_minsky_draw #(
 parameter F=17,K=8,PHASE_BITS=5,PHASE_ADD=15,PHASE_INITIAL=16,MICRO_BASE=4
);
 reg clk=0,rst=1,request=0;always #10 clk=~clk;
 reg [11:0] angle_bcd=0;reg direction_up=1;reg [5:0] radius=0;reg radius_valid=0;
 wire ready,done,bus_ready,bus_done,initialized,init_request,init_a0,draw_request,draw_read,draw_a0,oe;
 wire [7:0] dropped,init_data,draw_data,read_data,data_out,lcd_data;
 wire rd,wr,a0,res,cs;
 radar_lcd_micro #(.ENABLE_READBACK(1),.P5_FIXES(1),.FRACTION_BITS(F),.ROT_SHIFT(K),.PHASE_BITS(PHASE_BITS),.PHASE_ADD(PHASE_ADD),.PHASE_INITIAL(PHASE_INITIAL),.MICRO_BASE(MICRO_BASE)) dut(
  .continuous_mode(1'b0),.clk(clk),.rst(rst),.tick_ms(1'b1),.initialized(initialized),.lcd_rst_n(res),
  .request(request && initialized),.angle_bcd(angle_bcd),.direction_up(direction_up),.radius(radius),.radius_valid(radius_valid),
  .ready(ready),.done(done),.dropped(dropped),.bus_request(draw_request),.bus_read_op(draw_read),.bus_data_op(draw_a0),.bus_write_data(draw_data),
  .bus_ready(bus_ready),.bus_done(bus_done),.bus_read_data(read_data));
 lcd_bus_phase #(.ENABLE_READBACK(1)) bus(
  clk,rst,draw_request,draw_read,draw_a0,draw_data,lcd_data,data_out,oe,bus_ready,bus_done,read_data,rd,wr,a0,cs);
 assign lcd_data=oe?data_out:8'bz;
 st7565_model model(res,cs,rd,wr,a0,oe,lcd_data);
 reg [31:0] scenarios[0:`DRAW_SCENARIOS-1];
 reg [18:0] pixels[0:`DRAW_PIXELS-1];
 reg signed [F+1:0] expected_c[0:180],expected_s[0:180];
 reg [7:0] expected_ram[0:1055];
 integer cycles=0,accepted_cycle=0,scenario=0,ptr=0,tx=0,commands=0,a_count=0,b_count=0;
 integer i,j,index,old_ptr,old_a,old_b,expected_a,wall_cycles,deadline_failures=0,max_cycles=0,max_endpoint_cycles=0;
 integer wanted_drops=0,timefile,expected_ops,wanted_angle,accepted=0,ray_index,ray_number=0;
 reg accepted_direction;
 reg [7:0] wanted;
 reg want_read,want_data;
 wire [18:0] pixel=pixels[ptr];
 wire [2:0] ep=pixel[17:15];wire [6:0] ec=pixel[14:8];wire [7:0] em=pixel[7:0];
 function integer from_bcd;
  input [11:0] value;begin from_bcd=value[11:8]*100+value[7:4]*10+value[3:0];end
 endfunction
 always @(posedge clk) begin
  cycles=cycles+1;
  if(initialized && dut.accept) begin accepted_cycle=cycles;accepted=accepted+1;end
  if(initialized && dut.state==5) begin
   if(dut.erase) a_count=a_count+1;else b_count=b_count+1;
   if(dut.erase) begin
    if(expected_a==11) ray_index=(wanted_angle==180?170:0)+ray_number;
    else ray_index=wanted_angle;
    ray_number=ray_number+1;
   end else begin
    ray_index=wanted_angle;
    if(ray_number!=expected_a) $fatal(1,"B started before all expected A rays");
   end
   if(dut.c!==expected_c[ray_index] || dut.s!==expected_s[ray_index])
    $fatal(1,"Minsky vector mismatch scenario=%0d ray=%0d c=%0d expected=%0d s=%0d expected=%0d",scenario,ray_index,dut.c,expected_c[ray_index],dut.s,expected_s[ray_index]);
  end
  if(initialized && draw_request && bus_ready) begin
   if(ptr>=`DRAW_PIXELS) $fatal(1,"Unexpected extra RMW pixel");
   index=ep*132+ec;want_read=tx==3 || tx==4;want_data=want_read || tx==7;
   case(tx)
    0:wanted=8'hb0|ep;
    1,5:wanted=8'h10|(ec>>4);
    2,6:wanted=ec&15;
    7:wanted=pixel[18] ? expected_ram[index]&~em : expected_ram[index]|em;
    default:wanted=0;
   endcase
   if(draw_read!==want_read || draw_a0!==want_data)
    $fatal(1,"RMW control/order mismatch scenario=%0d pixel=%0d tx=%0d",scenario,ptr,tx);
   if(!want_read && draw_data!==wanted)
    $fatal(1,"RMW data/address mismatch scenario=%0d pixel=%0d tx=%0d got=%h expected=%h step=%0d ray=%0d",scenario,ptr,tx,draw_data,wanted,dut.step,ray_index);
   if(tx==7) begin expected_ram[index]=wanted;ptr=ptr+1;tx=0;end else tx=tx+1;
   commands=commands+1;
  end
 end
 task step_clock;begin @(negedge clk);end endtask
 task snapshot;
  input [511:0] name;integer file,y,x;
  begin
   file=$fopen(name,"w");$fwrite(file,"P1\n128 64\n");
   for(y=0;y<64;y=y+1) begin
    for(x=0;x<128;x=x+1) $fwrite(file,"%0d ",(model.ram[(y/8)*132+x]>>(y%8))&1);
    $fwrite(file,"\n");
   end
   $fclose(file);
  end
 endtask
 initial begin
  $readmemh("scenarios.hex",scenarios);$readmemh("pixels.hex",pixels);
  $readmemh("vectors_c.hex",expected_c);$readmemh("vectors_s.hex",expected_s);
  for(j=0;j<1056;j=j+1) expected_ram[j]=0;
  timefile=$fopen("busy_walltime.csv","w");
  $fwrite(timefile,"scenario,angle,direction_up,radius,valid,erase_rays,rmw_pixels,busy_cycles,busy_ns,under_1ms,dropped\n");
  repeat(4) step_clock;rst=0;wait(initialized);step_clock;
  for(scenario=0;scenario<`DRAW_SCENARIOS;scenario=scenario+1) begin
   wait(ready);step_clock;
   angle_bcd=scenarios[scenario][31:20];direction_up=scenarios[scenario][19];
   radius=scenarios[scenario][18:13];radius_valid=scenarios[scenario][12];
   wanted_angle=from_bcd(angle_bcd);expected_ops=scenarios[scenario][11:0];
   accepted_direction=direction_up;ray_number=0;
   expected_a=(wanted_angle==180 && !direction_up)||(wanted_angle==0 && direction_up)?11:
              1;
   old_ptr=ptr;old_a=a_count;old_b=b_count;request=1;step_clock;request=0;step_clock;
   if(dut.target_radius!==(radius<6?6:radius) || dut.target_valid!==(radius_valid && radius<=48))
    $fatal(1,"Request latch or min6/valid-radius policy failed scenario=%0d",scenario);
   // Corrupt external arguments and issue requests while busy. They must not
   // alter this drawing, its original sample angle, or its latched target.
   angle_bcd=12'h137;direction_up=~direction_up;radius=63;radius_valid=0;
   // No request strobe: external changes must not alter snapshot.
   wait(done);#1;wall_cycles=cycles-accepted_cycle;
   if(wall_cycles>max_cycles) max_cycles=wall_cycles;
   if(expected_a==11 && wall_cycles>max_endpoint_cycles) max_endpoint_cycles=wall_cycles;
   if(expected_a==11 ? wall_cycles>1000000 : wall_cycles>=50000) deadline_failures=deadline_failures+1;
   if(ptr-old_ptr!=expected_ops || tx!=0 || a_count-old_a!=expected_a || b_count-old_b!=1)
    $fatal(1,"A/B/ray/pixel totals incorrect scenario=%0d A=%0d/%0d B=%0d pixels=%0d/%0d",scenario,a_count-old_a,expected_a,b_count-old_b,ptr-old_ptr,expected_ops);
   if(dropped!==wanted_drops) $fatal(1,"Busy drop counter incorrect scenario=%0d got=%0d expected=%0d",scenario,dropped,wanted_drops);
   for(j=0;j<1056;j=j+1) if(model.ram[j]!==expected_ram[j])
    $fatal(1,"LCD RAM corruption scenario=%0d address=%0d got=%h expected=%h",scenario,j,model.ram[j],expected_ram[j]);
   $fwrite(timefile,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",scenario,wanted_angle,scenarios[scenario][19],scenarios[scenario][18:13],scenarios[scenario][12],expected_a,expected_ops,wall_cycles,wall_cycles*20,wall_cycles<50000,dropped);
   if(scenario==`FULL_INDEX) snapshot("full_scan.pbm");
   step_clock;
  end
  snapshot("multiple_targets_turnaround.pbm");$fclose(timefile);
  if(ptr!=`DRAW_PIXELS || commands!=`DRAW_PIXELS*8 || accepted!=`DRAW_SCENARIOS)
   $fatal(1,"Final transaction/accepted totals incorrect");
  $display("PASS_FUNCTIONAL Minsky draw F=%0d K=%0d scenarios=%0d pixels=%0d A=%0d B=%0d bus_transactions=%0d dropped=%0d; all pixels/RAM/order/vector/latches verified",F,K,accepted,ptr,a_count,b_count,commands,dropped);
  $display("TIMING_RESULT max_busy_cycles=%0d max_busy_ns=%0d endpoint_max_cycles=%0d endpoint_max_ns=%0d requests_failing_applicable_limit=%0d",max_cycles,max_cycles*20,max_endpoint_cycles,max_endpoint_cycles*20,deadline_failures);
  if(deadline_failures) $fatal(1,"DEADLINE_FAIL: ordinary must finish below 1ms; endpoint at most 20ms");
  $display("PASS step1_basic merged=0");$finish;
 end
 initial begin #3000000000;$fatal(1,"Minsky draw timeout");end
endmodule
