`timescale 1ns/1ps
`include "fixture.vh"
module tb_render #(parameter REAL_TIMING=0,parameter PRODUCTION_INIT=0);
 reg clk=0;always #10 clk=~clk;
 reg rst=1,request=0;
 reg stop_request=0;
 wire quiescent;
 reg [15:0] ms_divider=0;
 always @(posedge clk)begin
  if(rst || initialized)ms_divider<=0;
  else if(ms_divider==49999)ms_divider<=0;
  else ms_divider<=ms_divider+1'b1;
 end
 wire tick_ms=PRODUCTION_INIT ? (!initialized && ms_divider==49999) : 1'b1;
 reg [11:0] angle_bcd=0;
 reg direction_up=1,radius_valid=0;
 reg [5:0] radius=0;
 wire initialized,lcd_rst_n,ready,done;
 wire [7:0] dropped,bus_write_data,bus_read_data;
 wire bus_request,bus_read_op,bus_data_op,bus_ready,bus_done;
 radar_lcd_micro #(.ENABLE_READBACK(1),.P5_FIXES(1),.P5_UFM(1),.P5_UFM_BYTE(1),.P5_INVERT(1) `P5_CORE_BEAM_PARAMETER) dut(
  .clk(clk),.rst(rst),.request(request),.tick_ms(tick_ms),
  .continuous_mode(1'b`CONTINUOUS_MODE),.initialized(initialized),.lcd_rst_n(lcd_rst_n),
  .alarm_active(1'b0),.inverse_phase(1'b0),
  .angle_bcd(angle_bcd),.direction_up(direction_up),.radius(radius),.radius_valid(radius_valid),
  .ready(ready),.done(done),.dropped(dropped),
  .bus_request(bus_request),.bus_read_op(bus_read_op),.bus_data_op(bus_data_op),
  .bus_write_data(bus_write_data),.bus_ready(bus_ready),.bus_done(bus_done),.bus_read_data(bus_read_data) `P5_CORE_BEAM_PORTS);
 lcd_ram_bfm #(.REAL_TIMING(REAL_TIMING)) lcd(.clk(clk),.rst(rst),.request(bus_request),.read_op(bus_read_op),
  .data_op(bus_data_op),.write_data(bus_write_data),.ready(bus_ready),.done(bus_done),.read_data(bus_read_data));
 reg [19:0] cases[0:`REQUEST_COUNT-1];
 reg [7:0] expected[0:`REQUEST_COUNT*1056-1];
 reg [7:0] initial_expected[0:1055];
`ifdef P5_BEAM_TEST
 reg [7:0] unbeamed_expected[0:`REQUEST_COUNT*1056-1];
 integer removed_checks=0,beam_j,wanted_angle,integer_checks=0,change_address;
 integer withdraw_file,withdraw_read_start,withdraw_write_start;
 time withdraw_start;
 always @(posedge clk)if(!rst && initialized && dut.start_beam_remove)begin
  withdraw_start=$time;withdraw_read_start=read_cycles;withdraw_write_start=write_cycles;
 end
 reg [7:0] integer_expected[0:8868];
 reg step_checked[0:48];
 always @(posedge clk)if(!rst && initialized)begin
  if(dut.state==5)for(change_address=0;change_address<49;change_address=change_address+1)step_checked[change_address]=0;
  if(dut.state==6 && dut.beam_task)begin
   change_address=dut.beam_angle*49+dut.step;
   if(dut.integer_changed!==integer_expected[change_address][0])
    $fatal(1,"integer_changed differs from Python angle=%0d step=%0d got=%b expected=%b",dut.beam_angle,dut.step,dut.integer_changed,integer_expected[change_address][0]);
   if(dut.selected!==((dut.step>=6) && ((dut.step==6)||integer_expected[change_address][0])))
    $fatal(1,"Beam dedup selection differs from Python");
   if(!step_checked[dut.step])begin integer_checks=integer_checks+1;step_checked[dut.step]=1;end
  end
 end
 always @(posedge clk)if(!rst && initialized && dut.beam_remove_done)begin
  if(i<=0)$fatal(1,"Unexpected removal before a beam was drawn");
  for(beam_j=0;beam_j<1056;beam_j=beam_j+1)
   if(lcd.ram[beam_j]!==unbeamed_expected[(i-1)*1056+beam_j])
    $fatal(1,"Removed beam differs from no-beam model before request=%0d addr=%0d",i,beam_j);
  removed_checks=removed_checks+1;
  $fdisplay(withdraw_file,"%0d,%0d,%0d,%0d,%0d",i,dut.beam_angle,($time-withdraw_start)/20,read_cycles-withdraw_read_start,write_cycles-withdraw_write_start);
 end
`endif
 reg [15:0] ufm_expected[0:511];
 integer init_ufm_requests=0,init_ufm_words=0;
 integer copy_start_cycle=-1;
 integer i,j,wait_count,actual_file,cycles=0,max_frame_cycles=0,frame_start;
 integer timing_file,read_cycles=0,write_cycles=0,ufm_cycles=0,other_cycles=0;
 integer r_start,w_start,u_start,o_start,fetch_start;
 reg seen_lcd[0:1055];
 reg seen_ufm[0:1055];
 reg seen_write[0:1055];
 reg ray_active=0,ray_erases=0;
 integer monitor_addr,k,rmw_bytes=0,ufm_reads=0;
 // Observe endpoint transactions independently of requested expected image.
 // The LCD model records the address associated with its read buffer, so the
 // extra column increment caused by dummy/real reads cannot hide duplicates.
 task check_ray;
  begin
   if(ray_active)begin
    for(k=0;k<1056;k=k+1) begin
     if(ray_erases && seen_lcd[k]!==seen_ufm[k])
      $fatal(1,"A ray LCD/UFM byte mismatch addr=%0d lcd=%0b ufm=%0b",k,seen_lcd[k],seen_ufm[k]);
     if(!ray_erases && seen_ufm[k])$fatal(1,"B ray unexpectedly reads UFM");
     if(seen_write[k]!==seen_lcd[k])$fatal(1,"RMW read/write byte set differs addr=%0d",k);
    end
   end
  end
 endtask
 always @(posedge clk) if(!rst && initialized) begin
  if(dut.state==5)begin
   check_ray;
   for(k=0;k<1056;k=k+1)begin seen_lcd[k]=0;seen_ufm[k]=0;seen_write[k]=0;end
   ray_active=1;ray_erases=dut.erase;
`ifdef P5_BEAM_TEST
   ray_erases=dut.erase && !dut.beam_task;
`endif
  end
  if(lcd.pending && lcd.remaining==0 && lcd.held_read && !lcd.dummy)begin
   monitor_addr=lcd.buffer_address;
   if(!ray_active)$fatal(1,"LCD RMW outside ray");
   if(seen_lcd[monitor_addr])$fatal(1,"Repeated LCD read within ray addr=%0d",monitor_addr);
   seen_lcd[monitor_addr]=1;rmw_bytes=rmw_bytes+1;
  end
  if(lcd.pending && lcd.remaining==0 && !lcd.held_read && lcd.held_data && dut.state==9)begin
   monitor_addr=lcd.page*132+lcd.col;
   if(!ray_active || seen_write[monitor_addr])$fatal(1,"Repeated LCD data write within ray addr=%0d",monitor_addr);
   if(!seen_lcd[monitor_addr])$fatal(1,"RMW data write without preceding LCD read addr=%0d",monitor_addr);
   seen_write[monitor_addr]=1;
  end
  if(dut.ufm_request && !dut.ufm_busy)begin
   monitor_addr=dut.byte_page*132+dut.byte_col;
   if(!ray_active || !ray_erases)$fatal(1,"UFM read outside A ray");
   if(seen_ufm[monitor_addr])$fatal(1,"Repeated UFM read within ray addr=%0d",monitor_addr);
   if(dut.g_background_byte.background_reader.operation!==2'd0 ||
      dut.g_background_byte.background_reader.low_byte!==dut.byte_col[0] ||
      dut.g_background_byte.background_reader.address!=={dut.byte_page,dut.byte_col[6:1]})
    $fatal(1,"A random UFM byte address/parity mismatch");
   seen_ufm[monitor_addr]=1;ufm_reads=ufm_reads+1;
  end
 end
 always @(posedge clk) cycles<=cycles+1;
 always @(posedge clk)if(!rst)begin
  if(lcd.pending || (bus_request && bus_ready && !bus_done))begin
   if(lcd.pending ? lcd.held_read : bus_read_op)read_cycles=read_cycles+1;
   else write_cycles=write_cycles+1;
  end else if(dut.ufm_busy || dut.ufm_request)ufm_cycles=ufm_cycles+1;
  else other_cycles=other_cycles+1;
 end
 always @(posedge clk) if(!rst && !initialized)begin
  if(dut.ufm_request && !dut.ufm_busy)begin
   if(init_ufm_requests==0)copy_start_cycle=cycles;
   if(init_ufm_requests>=1024)$fatal(1,"Too many initialization UFM requests");
   if(dut.g_background_byte.background_reader.operation !==
      ((init_ufm_requests%2) ? 2'd2 : init_ufm_requests==0 ? 2'd0 : 2'd1))
    $fatal(1,"Initialization must random-high once, increment-high then tail-low");
   if(dut.g_background_byte.background_reader.low_byte !== (init_ufm_requests%2!=0))
    $fatal(1,"Initialization high/low byte parity mismatch");
   if(init_ufm_requests==0 && dut.g_background_byte.background_reader.address!==9'd0)
    $fatal(1,"Initialization first UFM address must be 0");
   init_ufm_requests=init_ufm_requests+1;
  end
  if(dut.ufm_done)begin
   if(dut.ufm_word[7:0]!==((init_ufm_words%2) ? ufm_expected[init_ufm_words/2][7:0] : ufm_expected[init_ufm_words/2][15:8]))
    $fatal(1,"Initialization UFM sequence mismatch word=%0d",init_ufm_words);
   init_ufm_words=init_ufm_words+1;
  end
 end
 task step;
  begin @(posedge clk);#1;end
 endtask
 task compare_initial;
  begin
   for(j=0;j<1056;j=j+1)
    if(lcd.ram[j]!==initial_expected[j]) $fatal(1,"INIT mismatch page=%0d col=%0d actual=%02x expected=%02x",j/132,j%132,lcd.ram[j],initial_expected[j]);
   if(lcd.reads!=0) $fatal(1,"Initialization must not read LCD RAM");
   if(init_ufm_requests!=1024 || init_ufm_words!=1024)$fatal(1,"Initialization UFM byte count mismatch req=%0d done=%0d",init_ufm_requests,init_ufm_words);
   $display("INIT_PASS cycles=%0d writes=%0d ufm=%0d lcd_read=%0d lcd_write=%0d overhead=%0d",cycles,lcd.writes,ufm_cycles,read_cycles,write_cycles,other_cycles);
   $display("INIT_COPY first_ufm_cycle=%0d through_display_on_cycles=%0d production_tick=%0d",copy_start_cycle,cycles-copy_start_cycle,PRODUCTION_INIT);
  end
 endtask
 initial begin
  $readmemh("requests.mem",cases);
  $readmemh("expected.mem",expected);
  $readmemh("initial_expected.mem",initial_expected);
  $readmemh("background.mem",ufm_expected);
`ifdef P5_BEAM_TEST
  $readmemh("unbeamed_expected.mem",unbeamed_expected);
  $readmemh("integer_changed.mem",integer_expected);
`endif
  actual_file=$fopen("actual.mem","w");
  timing_file=$fopen("timing.csv","w");
`ifdef P5_BEAM_TEST
  withdraw_file=$fopen("withdraw_timing.csv","w");
  $fdisplay(withdraw_file,"request,angle,total_cycles,lcd_read_cycles,lcd_write_cycles");
`endif
  $fdisplay(timing_file,"request,angle_bcd,total_cycles,ufm_cycles,lcd_read_cycles,lcd_write_cycles,overhead_cycles,ufm_fetches");
  repeat(5)step;rst=0;
  wait_count=0;
  while(!initialized && wait_count<10000000) begin step;wait_count=wait_count+1;end
  if(!initialized) $fatal(1,"Initialization timeout");
  compare_initial;
  for(i=0;i<`REQUEST_COUNT;i=i+1) begin
   while(!ready)step;
   angle_bcd=cases[i][19:8];direction_up=cases[i][7];radius_valid=cases[i][6];radius=cases[i][5:0];
   frame_start=cycles;r_start=read_cycles;w_start=write_cycles;u_start=ufm_cycles;o_start=other_cycles;
   fetch_start=ufm_reads;
   request=1;step;request=0;
   wait_count=0;
   while(!done && wait_count<2000000) begin step;wait_count=wait_count+1;end
   if(!done)$fatal(1,"Request timeout index=%0d",i);
   check_ray;
`ifdef P5_BEAM_TEST
   wanted_angle=angle_bcd[11:8]*100+angle_bcd[7:4]*10+angle_bcd[3:0];
   if(dut.beam_valid!==1'b1)$fatal(1,"Full beam must exist after every request=%0d",i);
   if(dut.beam_angle!=wanted_angle)$fatal(1,"Stored beam angle mismatch request=%0d",i);
`endif
   if(cycles-frame_start>max_frame_cycles)max_frame_cycles=cycles-frame_start;
   $fdisplay(timing_file,"%0d,%03x,%0d,%0d,%0d,%0d,%0d,%0d",i,angle_bcd,cycles-frame_start,ufm_cycles-u_start,read_cycles-r_start,write_cycles-w_start,other_cycles-o_start,ufm_reads-fetch_start);
   for(j=0;j<1056;j=j+1) begin
    $fdisplay(actual_file,"%02x",lcd.ram[j]);
    if(lcd.ram[j]!==expected[i*1056+j])
     $fatal(1,"FRAME mismatch index=%0d angle_bcd=%03x page=%0d col=%0d actual=%02x expected=%02x",i,angle_bcd,j/132,j%132,lcd.ram[j],expected[i*1056+j]);
   end
   if(i%180==0)$display("FRAME_PASS index=%0d cycles=%0d",i,cycles-frame_start);
   step;
  end
`ifdef P5_BEAM_TEST
  // Exercise the same quiesce request used before a mode switch/reset.
  stop_request=1;wait_count=0;
  while(!quiescent && wait_count<2000000)begin step;wait_count=wait_count+1;end
  if(!quiescent || dut.beam_valid)$fatal(1,"Stop did not withdraw beam before quiescence");
  for(j=0;j<1056;j=j+1)
   if(lcd.ram[j]!==unbeamed_expected[(`REQUEST_COUNT-1)*1056+j])$fatal(1,"Stop RAM mismatch addr=%0d",j);
  $display("BEAM_REMOVE_PASS comparisons=%0d",removed_checks);
  $display("INTEGER_CHANGE_PASS unique_radial_checks=%0d full_radius_6_to_48=1",integer_checks);
  $fclose(withdraw_file);
`endif
  $fclose(actual_file);
  $fclose(timing_file);
  if(dropped!=0)$fatal(1,"Unexpected merges=%0d",dropped);
  $display("PASS render mode=%0d requests=%0d max_frame_cycles=%0d rmw_bytes=%0d ufm_reads=%0d real_timing=%0d",`CONTINUOUS_MODE,`REQUEST_COUNT,max_frame_cycles,rmw_bytes,ufm_reads,REAL_TIMING);
  $finish;
 end
endmodule
