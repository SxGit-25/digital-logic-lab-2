`timescale 1ns/1ps
// The real global timebase runs at its supported 1 MHz setting, with a 1 us
// physical clock. Thus rhythm_phase[1] still changes every physical 250 ms.
module tb_alarm_inverse;
 reg clk=0;always #500 clk=~clk;
 reg rst=1,enabled=1,current_valid=0;
 reg request=0;
 reg [11:0] angle_bcd=12'h090;
 reg [5:0] radius=24;
 reg [1:0] system_state=3;
 reg [2:0] current_level=0;
 wire [2:0] rhythm_phase;
 wire inverse_phase=rhythm_phase[1];
 wire alarm_active=enabled && system_state==3 && current_valid && current_level==5;
 radar_global_timebase_alarm #(.CLK_HZ(1000000)) timebase(
  .clk(clk),.rst(rst),.display_index(3'd0),.rhythm_phase(rhythm_phase));
 wire initialized,lcd_rst_n,bus_request,bus_read_op,bus_data_op,bus_ready,bus_done,ready,done;
 wire [7:0] bus_write_data,bus_read_data;
 radar_lcd_micro #(.ENABLE_READBACK(1),.P5_FIXES(1),.P5_UFM(1),.P5_INVERT(1)) dut(
  .clk(clk),.rst(rst),.tick_ms(1'b1),.request(request),.continuous_mode(1'b1),
  .alarm_active(alarm_active),.inverse_phase(inverse_phase),
  .angle_bcd(angle_bcd),.direction_up(1'b1),.radius(radius),.radius_valid(1'b1),
  .initialized(initialized),.lcd_rst_n(lcd_rst_n),.ready(ready),.done(done),
  .bus_request(bus_request),.bus_read_op(bus_read_op),.bus_data_op(bus_data_op),
  .bus_write_data(bus_write_data),.bus_ready(bus_ready),.bus_done(bus_done),.bus_read_data(bus_read_data));
 lcd_ram_bfm #(.REAL_TIMING(1)) lcd(.clk(clk),.rst(rst),.request(bus_request),
  .read_op(bus_read_op),.data_op(bus_data_op),.write_data(bus_write_data),
  .ready(bus_ready),.done(bus_done),.read_data(bus_read_data));
 reg [7:0] baseline[0:1055],commands[0:31];
 reg [7:0] drawing_expected[0:2111];
 time command_time[0:31],last_phase_edge=0;
 integer command_count=0,phase_edges=0,i,j,old_count,wait_cycles;
 integer data_writes,reads;
 time edge_time;
 always @(inverse_phase)if(!rst && initialized)begin
  if(last_phase_edge && $time-last_phase_edge!=250000000)
   $fatal(1,"Global phase interval is not 250 ms: %0t",$time-last_phase_edge);
  last_phase_edge=$time;phase_edges=phase_edges+1;
 end
 always @(posedge clk)if(!rst && initialized)begin
  if(dut.state==22 && bus_request && (bus_read_op || bus_data_op))
   $fatal(1,"Inversion must be a command, never RAM read/write");
  if(lcd.pending && lcd.remaining==0 && !lcd.held_read && !lcd.held_data)begin
   if(lcd.held_byte==8'ha5)$fatal(1,"Unexpected all-pixels-on command A5");
   if(lcd.held_byte==8'ha6 || lcd.held_byte==8'ha7)begin
    commands[command_count]=lcd.held_byte;
    command_time[command_count]=$time;
    command_count=command_count+1;
   end
  end
 end
 task step;
  begin @(negedge clk);end
 endtask
 task expect_command;
  input [7:0] wanted;
  input integer before_count;
  begin
   wait_cycles=0;
   while(command_count==before_count && wait_cycles<40)begin step;wait_cycles=wait_cycles+1;end
   if(command_count!=before_count+1 || commands[before_count]!==wanted)
    $fatal(1,"Inverse command mismatch wanted=%h count=%0d before=%0d",wanted,command_count,before_count);
   repeat(5)step;
  end
 endtask
 task unchanged;
  begin
   if(lcd.writes!=data_writes || lcd.reads!=reads)$fatal(1,"Alarm caused LCD RAM traffic");
   for(j=0;j<1056;j=j+1)if(lcd.ram[j]!==baseline[j])$fatal(1,"Alarm modified RAM addr=%0d",j);
  end
 endtask
 initial begin
  $readmemh("alarm_expected.mem",drawing_expected);
  repeat(5)step;rst=0;wait(initialized);step;
  for(j=0;j<1056;j=j+1)baseline[j]=lcd.ram[j];
  data_writes=lcd.writes;reads=lcd.reads;
  current_valid=1;
  // Lower levels, invalid highest and disabled outputs must never alarm.
  for(i=0;i<5;i=i+1)begin current_level=i;repeat(40)step;end
  current_level=5;current_valid=0;repeat(40)step;
  current_valid=1;enabled=0;repeat(40)step;
  enabled=1;system_state=2;repeat(40)step;
  if(command_count!=0)$fatal(1,"Non-highest/invalid/disabled state alarmed");
  system_state=3;
  if(inverse_phase!==0)$fatal(1,"Test entry must precede first 250 ms edge");
  // Four consecutive physical 250 ms edges, including both A7 and A6.
  for(i=0;i<4;i=i+1)begin
   old_count=command_count;@(inverse_phase);edge_time=$time;
   expect_command(inverse_phase ? 8'ha7 : 8'ha6,old_count);
   $display("ALARM_PHASE_LATENCY clocks=%0d",(command_time[old_count]-edge_time)/1000);
   if(command_time[old_count]-edge_time>40000)$fatal(1,"Inversion command latency >40 clocks");
   if(i>0 && command_time[old_count]-command_time[old_count-1]!=250000000)
    $fatal(1,"Alternating command interval not 250 ms");
   unchanged;
  end
  // Alarm release while normal A6 is already active still forces A6 once.
  old_count=command_count;current_valid=0;
  expect_command(8'ha6,old_count);unchanged;
  // Re-enter at the next inverse phase; release must immediately force A6.
  @(posedge inverse_phase);current_valid=1;old_count=command_count;
  expect_command(8'ha7,old_count);unchanged;
  old_count=command_count;current_valid=0;
  expect_command(8'ha6,old_count);unchanged;
  old_count=command_count;
  @(negedge inverse_phase);repeat(40)step;
  if(command_count!=old_count)$fatal(1,"Alarm-free phase edge emitted a command");
  unchanged;
  // Start a real UFM A/B frame 10 us before the next global 250 ms edge.
  // The new inversion command must wait for the unified renderer to finish.
  current_valid=1;
  while(!(timebase.ms_in_125==124 && timebase.us_in_ms==990 && rhythm_phase[0]))step;
  old_count=command_count;request=1;step;request=0;
  @(posedge inverse_phase);edge_time=$time;
  if(dut.state==0)$fatal(1,"Concurrent phase edge did not occur during drawing");
  while(!done)begin
   step;if(command_count!=old_count)$fatal(1,"Inversion bypassed busy drawing");
  end
  for(j=0;j<1056;j=j+1)if(lcd.ram[j]!==drawing_expected[j])$fatal(1,"Concurrent alarm frame1 mismatch addr=%0d",j);
  expect_command(8'ha7,old_count);
  $display("BUSY_ALARM_LATENCY kind=phase event_to_command_clocks=%0d",(command_time[old_count]-edge_time)/1000);
  for(j=0;j<1056;j=j+1)if(lcd.ram[j]!==drawing_expected[j])$fatal(1,"A7 changed frame1 addr=%0d",j);
  while(!ready)step;
  angle_bcd=12'h091;radius=31;old_count=command_count;
  request=1;step;request=0;
  while(dut.state!=9)step;
  current_valid=0;edge_time=$time;
  while(!done)begin
   step;if(command_count!=old_count)$fatal(1,"Alarm release bypassed busy drawing");
  end
  for(j=0;j<1056;j=j+1)if(lcd.ram[j]!==drawing_expected[1056+j])$fatal(1,"Concurrent alarm frame2 mismatch addr=%0d",j);
  expect_command(8'ha6,old_count);
  $display("BUSY_ALARM_LATENCY kind=release event_to_command_clocks=%0d",(command_time[old_count]-edge_time)/1000);
  for(j=0;j<1056;j=j+1)if(lcd.ram[j]!==drawing_expected[1056+j])$fatal(1,"A6 changed frame2 addr=%0d",j);
  $display("CONCURRENT_ALARM_PASS frames=2 Python_expected_bytes=2112 busy_commands_deferred=1");
  $display("PASS alarm_inverse commands=%0d phase_edges=%0d phase_period_ns=250000000 normal_release_A6=1 inverse_release_A6=1 ram_unchanged=1056 no_A5=1",command_count,phase_edges);
  $finish;
 end
 initial begin #2000000000;$fatal(1,"Alarm test timeout");end
endmodule
