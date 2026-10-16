`timescale 1ns/1ps
module tb_p5_ufm_byte_reader;
 reg clk=0,rst=1,request=0,low_byte=0;
 reg [1:0] operation=0;
 reg [8:0] address=0;
 wire busy,done;
 wire [7:0] value;
 reg [15:0] expected[0:511];
 integer expected_address=0,checks=0,ar_pulses=0,dr_pulses=0,loads=0;
 integer phase_random=0,phase_increment=0,phase_tail=0;
 integer min_random_high=10000,max_random_high=0,min_random_low=10000,max_random_low=0;
 integer min_increment_high=10000,max_increment_high=0,min_tail=10000,max_tail=0;
 reg [8:0] serial_address=0;
 realtime last_ar=-1000,last_dr=-1000,last_af=-1000,last_df=-1000;
 realtime last_address=-1000,last_arshft=-1000,last_drshft=-1000;
 realtime min_as=100000,min_ahs=100000,min_ds=100000,min_ah=100000,min_dh=100000;
 always #10 clk=~clk;
 p5_ufm_byte_reader dut(.*);
 initial $readmemh("background.mem",expected);
 always @(dut.addr_shift[8])begin
  if(!rst && $realtime-last_ar<20)$fatal(1,"ARDIN hold");
  if(!rst && $realtime-last_ar<min_ah)min_ah=$realtime-last_ar;
  last_address=$realtime;
 end
 always @(dut.arshft)begin
  if(!rst && $realtime-last_ar<20)$fatal(1,"ARSHFT hold");
  last_arshft=$realtime;
 end
 always @(dut.drshft)begin
  if(!rst && $realtime-last_dr<20)$fatal(1,"DRSHFT hold");
  if(!rst && $realtime-last_dr<min_dh)min_dh=$realtime-last_dr;
  last_drshft=$realtime;
 end
 always @(posedge dut.arclk)begin
  if($realtime-last_ar<320 || $realtime-last_af<160)$fatal(1,"ARCLK period/low");
  if($realtime-last_address<20 || $realtime-last_arshft<20)$fatal(1,"AR setup");
  if($realtime-last_address<min_as)min_as=$realtime-last_address;
  if($realtime-last_arshft<min_ahs)min_ahs=$realtime-last_arshft;
  if(dut.arshft)serial_address={serial_address[7:0],dut.addr_shift[8]};
  else serial_address=serial_address+1'b1;
  ar_pulses=ar_pulses+1;last_ar=$realtime;
 end
 always @(negedge dut.arclk)begin
  if(!rst && $realtime-last_ar<160)$fatal(1,"ARCLK high");last_af=$realtime;
 end
 always @(posedge dut.drclk)begin
  if($realtime-last_dr<320 || $realtime-last_df<160)$fatal(1,"DRCLK period/low");
  if($realtime-last_drshft<60)$fatal(1,"DRSHFT setup");
  if($realtime-last_drshft<min_ds)min_ds=$realtime-last_drshft;
  if(serial_address!==expected_address[8:0])$fatal(1,"MSB-first address mismatch");
  if(!dut.drshft)loads=loads+1;
  dr_pulses=dr_pulses+1;last_dr=$realtime;
 end
 always @(negedge dut.drclk)begin
  if(!rst && $realtime-last_dr<160)$fatal(1,"DRCLK high");last_df=$realtime;
 end
 task read_byte;
  input integer a;
  input [1:0] op;
  input low;
  input integer p;
  integer cycles,expected_dr,expected_ar;
  reg [7:0] want;
  begin
   @(negedge clk);
   if(p>=0)while(dut.phase!=p)@(negedge clk);
   if(busy)$fatal(1,"busy before request");
   expected_address=a;address=a;operation=op;low_byte=low;request=1;
   expected_dr=(low && !op[1]) ? 16 : 8;
   expected_ar=op[1] ? 0 : op[0] ? 1 : 9;
   want=(low || op[1]) ? expected[a][7:0] : expected[a][15:8];
   ar_pulses=0;dr_pulses=0;loads=0;
   if(p>=0)begin
    if(op==0)phase_random=phase_random|(1<<p);
    else if(op==1)phase_increment=phase_increment|(1<<p);
    else phase_tail=phase_tail|(1<<p);
   end
   @(negedge clk);request=0;cycles=0;
   while(!done && cycles<500)begin @(negedge clk);cycles=cycles+1;end
   if(!done || value!==want)$fatal(1,"byte a=%d op=%d low=%d got=%h want=%h cycles=%d",a,op,low,value,want,cycles);
   if(ar_pulses!=expected_ar || dr_pulses!=expected_dr || loads!=(op[1] ? 0 : 1))$fatal(1,"pulse/load count AR=%d DR=%d load=%d op=%d",ar_pulses,dr_pulses,loads,op);
   if(op==0 && !low)begin if(cycles<min_random_high)min_random_high=cycles;if(cycles>max_random_high)max_random_high=cycles;end
   if(op==0 && low)begin if(cycles<min_random_low)min_random_low=cycles;if(cycles>max_random_low)max_random_low=cycles;end
   if(op==1 && !low)begin if(cycles<min_increment_high)min_increment_high=cycles;if(cycles>max_increment_high)max_increment_high=cycles;end
   if(op==2)begin if(cycles<min_tail)min_tail=cycles;if(cycles>max_tail)max_tail=cycles;end
   checks=checks+1;
   // Early-stop check includes idle time beyond a complete serial period.
   repeat(18)@(negedge clk);
   if(done || busy || ar_pulses!=expected_ar || dr_pulses!=expected_dr)$fatal(1,"completion/early-stop");
  end
 endtask
 integer i,a,p;
 initial begin
  #100;@(negedge clk);rst=0;
  // Every word, both bytes, independent random reads in a permutation.
  for(i=0;i<512;i=i+1)begin
   a=(197*i+83)%512;repeat(i%16)@(negedge clk);
   read_byte(a,0,0,-1);read_byte(a,0,1,-1);
  end
  // Full sequential LCD order: high-byte first then tail low-byte.
  read_byte(0,0,0,-1);read_byte(0,2,1,-1);
  for(i=1;i<512;i=i+1)begin read_byte(i,1,0,-1);read_byte(i,2,1,-1);end
  read_byte(0,1,0,-1);read_byte(0,2,1,-1); // UFM address wraparound.
  for(p=0;p<16;p=p+1)begin
   a=256+p*7;read_byte(a,0,0,p);read_byte(a,2,1,p);
   read_byte(a,0,1,p);read_byte(a+1,1,1,p);
   read_byte(a+2,1,0,p);read_byte(a+2,2,1,p);
  end
  if(phase_random!=65535 || phase_increment!=65535 || phase_tail!=65535)$fatal(1,"phase coverage");
  $display("PASS UFM byte words512 both-byte random+sequential+wrap bytes=%0d phase masks=%h/%h/%h high-byte early-stop DR8 low-fresh DR16 tail DR8/AR0",checks,phase_random,phase_increment,phase_tail);
  $display("cycles random-high=%0d..%0d random-low=%0d..%0d increment-high=%0d..%0d tail=%0d..%0d",min_random_high,max_random_high,min_random_low,max_random_low,min_increment_high,max_increment_high,min_tail,max_tail);
  $display("min setup ns ARDIN=%0.0f ARSHFT=%0.0f DRSHFT=%0.0f hold ARDIN=%0.0f DRSHFT=%0.0f; clocks>=320ns high/low>=160ns output model delay180ns",min_as,min_ahs,min_ds,min_ah,min_dh);
  $finish;
 end
 initial begin #30000000;$fatal(1,"watchdog");end
endmodule
