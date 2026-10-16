`timescale 1ns/1ps
`ifdef P5_BUSY_STOP_TEST
`include "busy_mode.vh"
module tb_busy_stop;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,request=0,stop_request=0;
 reg [19:0] payload=0;
 wire initialized,ready,done,quiescent,bus_request,bus_read_op,bus_data_op,bus_ready,bus_done;
 wire [7:0] bus_write_data,bus_read_data;
 radar_lcd_micro #(.ENABLE_READBACK(1),.P5_FIXES(1),.P5_UFM(1),.P5_UFM_BYTE(1),.P5_INVERT(1),.P5_BEAM(1)) dut(
  .clk(clk),.rst(rst),.tick_ms(1'b1),.request(request),.stop_request(stop_request),.quiescent(quiescent),
  .continuous_mode(1'b`BUSY_CONTINUOUS),.alarm_active(1'b0),.inverse_phase(1'b0),
  .angle_bcd(payload[19:8]),.direction_up(payload[7]),.radius_valid(payload[6]),.radius(payload[5:0]),
  .initialized(initialized),.ready(ready),.done(done),
  .bus_request(bus_request),.bus_read_op(bus_read_op),.bus_data_op(bus_data_op),.bus_write_data(bus_write_data),
  .bus_ready(bus_ready),.bus_done(bus_done),.bus_read_data(bus_read_data));
 lcd_ram_bfm lcd(.clk(clk),.rst(rst),.request(bus_request),.read_op(bus_read_op),
  .data_op(bus_data_op),.write_data(bus_write_data),.ready(bus_ready),.done(bus_done),.read_data(bus_read_data));
 reg [19:0] inputs[0:9];
 reg [7:0] warm_expected[0:5279],stop_expected[0:5279];
 integer phase,j,wait_cycles,old_reads,old_writes;
 reg phase_reached;
 task step;begin @(posedge clk);#1;end endtask
 task launch;
  input [19:0] value;
  begin while(!ready)step;payload=value;request=1;step;request=0;end
 endtask
 initial begin
  $readmemh("busy_inputs.mem",inputs);
  $readmemh("warm_expected.mem",warm_expected);
  $readmemh("stop_expected.mem",stop_expected);
  repeat(5)step;rst=0;wait(initialized);step;
  for(phase=0;phase<5;phase=phase+1)begin
   launch(inputs[phase*2]);wait(done);step;
   if(!dut.beam_valid)$fatal(1,"Warmup did not draw a beam");
   for(j=0;j<1056;j=j+1)if(lcd.ram[j]!==warm_expected[phase*1056+j])$fatal(1,"Warmup mismatch phase=%0d addr=%0d",phase,j);
   launch(inputs[phase*2+1]);phase_reached=0;wait_cycles=0;
   while(!phase_reached && wait_cycles<2000000)begin
    step;wait_cycles=wait_cycles+1;
    case(phase)
     0:phase_reached=dut.state==11 && dut.flush_left==14;
     1:phase_reached=dut.beam_task && dut.flush_left==14 && dut.state==6;
     2:phase_reached=!dut.beam_task && dut.erase && dut.state==6;
     3:phase_reached=!dut.beam_task && !dut.erase && dut.state==6;
     4:phase_reached=dut.beam_task && dut.flush_left==15 && dut.state==6;
    endcase
   end
   if(!phase_reached)$fatal(1,"Stop phase not reached phase=%0d",phase);
   stop_request=1;wait_cycles=0;
   while(!quiescent && wait_cycles<2000000)begin step;wait_cycles=wait_cycles+1;end
   if(!quiescent || dut.beam_valid || dut.pending)$fatal(1,"Busy stop failed to quiesce phase=%0d",phase);
   for(j=0;j<1056;j=j+1)if(lcd.ram[j]!==stop_expected[phase*1056+j])
    $fatal(1,"Busy stop XOR residue phase=%0d addr=%0d actual=%h expected=%h",phase,j,lcd.ram[j],stop_expected[phase*1056+j]);
   old_reads=lcd.reads;old_writes=lcd.writes;repeat(20)step;
   if(lcd.reads!=old_reads || lcd.writes!=old_writes)$fatal(1,"RAM traffic after quiescence");
   $display("BUSY_STOP_PASS mode=%0d phase=%0d wait_clocks=%0d",`BUSY_CONTINUOUS,phase,wait_cycles);
   stop_request=0;step;
  end
  $display("PASS busy_stop mode=%0d phases=5 RAM_bytes_compared=10560 beam_valid_zero=1 pending_zero=1",`BUSY_CONTINUOUS);
  $finish;
 end
 initial begin #200000000;$fatal(1,"Busy stop timeout");end
endmodule
`endif
