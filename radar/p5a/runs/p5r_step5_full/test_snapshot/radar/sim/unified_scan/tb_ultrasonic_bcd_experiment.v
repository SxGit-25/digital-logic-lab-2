`timescale 1ns/1ps
module tb_ultrasonic_bcd_experiment;
 reg clk=0;always #10 clk=~clk;
 reg rst=1,start=0,cancel=0,echo=0;
 reg [5:0] us_phase=0;
 wire tick_us=us_phase==49;
 always @(posedge clk) if(rst) us_phase<=0;else if(tick_us) us_phase<=0;else us_phase<=us_phase+1'b1;
 wire old_trig,old_busy,old_done,old_valid,old_rv;
 wire [11:0] old_mm;wire [5:0] old_radius;wire [15:0] old_bcd;
 ultrasonic_bcd_legacy old(clk,rst,tick_us,start,cancel,echo,old_trig,old_busy,old_done,old_mm,old_valid,old_radius,old_rv);
 bin12_to_bcd_bcd_legacy old_converter(clk,rst,old_mm,old_bcd);
 wire [3:0] trig,busy,done,valid,rv;
 wire [15:0] bcd[0:3];wire [2:0] level[0:3];wire [5:0] radius[0:3];
 genvar g;
 generate for(g=0;g<4;g=g+1) begin : variants
  ultrasonic_bcd_experiment #(.DIVIDER_MODE(g==1),.RESET_PHASE_ON_ECHO(g!=3),.ROUND_NEAREST(g!=2)) dut(
   clk,rst,tick_us,start,cancel,echo,trig[g],busy[g],done[g],bcd[g],valid[g],level[g],radius[g],rv[g]);
 end endgenerate
 integer cycles=0,elapsed_clocks=0,free_ticks=0,free_phase=0,case_count=0,j,wanted,wanted_level,actual,logfile;
 function integer unpack_bcd;
  input [15:0] v;
  begin unpack_bcd=v[15:12]*1000+v[11:8]*100+v[7:4]*10+v[3:0];end
 endfunction
 always @(posedge clk) begin
  cycles=cycles+1;
  if(rst) begin free_phase=0;elapsed_clocks=0;free_ticks=0;end
  else begin
   if(cancel || (old.state==0 && start) || (old.state==3 && old.echo_rise)) begin elapsed_clocks=0;free_ticks=0;end
   else if(old.state==4 && !old.echo_fall && !(tick_us && old.budget_us==29999)) begin
    elapsed_clocks=elapsed_clocks+1;
    if(free_phase>=4983) free_ticks=free_ticks+1;
   end
   if(free_phase>=4983) free_phase=free_phase-4983;else free_phase=free_phase+17;
  end
  #1;
  if(trig!=={4{old_trig}} || busy!=={4{old_busy}} || done!=={4{old_done}})
   $fatal(1,"BCD experiment changed trig/busy/done timing cycle=%0d",cycles);
  if(old_done) begin
   case_count=case_count+1;
   for(j=0;j<4;j=j+1) begin
    case(j)
     0:wanted=(17*(elapsed_clocks+1)+2500)/5000;
     1:wanted=(elapsed_clocks+1+147)/294;
     2:wanted=(17*(elapsed_clocks+1))/5000;
     3:wanted=free_ticks;
    endcase
    if(old.echo_sync || wanted<20 || wanted>4000) wanted=0;
    actual=unpack_bcd(bcd[j]);
    if(actual!=wanted || valid[j]!=(wanted!=0)) $fatal(1,"BCD value case=%0d variant=%0d elapsed=%0d got=%0d expected=%0d",case_count,j,elapsed_clocks,actual,wanted);
    wanted_level=wanted==0?0:wanted>=800?1:wanted>=600?2:wanted>=400?3:wanted>=200?4:5;
    if(level[j]!==wanted_level || rv[j]!==((wanted!=0)&&(wanted<=1200)) || radius[j]!==((wanted==0)?0:(wanted/25>48?48:wanted/25)))
     $fatal(1,"BCD radius/level case=%0d variant=%0d mm=%0d r=%0d rv=%b level=%0d",case_count,j,wanted,radius[j],rv[j],level[j]);
    $fwrite(logfile,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",case_count,j,elapsed_clocks,old.echo_us,old_mm,old_valid,actual,valid[j],radius[j],rv[j]);
   end
  end
 end
 task step;begin @(negedge clk);end endtask
 task pulse_start;begin start=1;step;start=0;end endtask
 task finish_case;
  begin wait(old_done);repeat(20) step;if(unpack_bcd(old_bcd)!=old_mm) $fatal(1,"Legacy BCD converter did not settle");end
 endtask
 task echo_case;
  input integer us,phase,extra;
  begin
   echo=0;repeat(5) step;pulse_start;wait(!old_trig);repeat(20+phase) step;
   echo=1;repeat(us*50+extra) step;echo=0;finish_case;
  end
 endtask
 initial begin
  logfile=$fopen("bcd_samples.csv","w");
  $fwrite(logfile,"case,variant,count_clocks,legacy_echo_us,legacy_mm,legacy_valid,experiment_mm,experiment_valid,radius,radius_valid\n");
  repeat(4) step;rst=0;
  echo_case(115,0,0);echo_case(117,1,0);echo_case(118,17,0);
  echo_case(145,23,0);echo_case(1000,13,0);echo_case(1176,41,24);
  echo_case(7056,29,0);echo_case(7062,3,0);
  echo_case(23529,19,0);echo_case(23530,43,0);echo_case(24500,7,0);
  pulse_start;finish_case; // noecho after nonzero accumulator
  echo=1;repeat(5) step;pulse_start;finish_case;echo=0;repeat(5) step;
  pulse_start;wait(!old_trig);repeat(8) step;echo=1;
  repeat(10000) step;cancel=1;step;cancel=0;echo=0;repeat(5) step;
  if(|busy || |rv || |valid) $fatal(1,"BCD experiment cancel did not abort");
  rst=1;step;rst=0;repeat(5) step;
  if(case_count!=13) $fatal(1,"BCD experiment incomplete cases");
  $fclose(logfile);
  $display("PASS tb_ultrasonic_bcd_experiment cycles=%0d cases=%0d variants=4: fractional rounded, integer294 rounded, fractional floor, fractional free-running; independent numerical/radius/BCD-level oracle; legacy trig/busy/done cycle-identical",cycles,case_count);
  $finish;
 end
 initial begin #250000000;$fatal(1,"BCD experiment timeout");end
endmodule
