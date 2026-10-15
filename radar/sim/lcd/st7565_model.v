`timescale 1ns/1ps
module st7565_model(input wire rst_n,cs_n,rd_n,wr_n,a0,
 input wire host_oe, inout wire [7:0] data);
 reg [7:0] ram[0:1055];
 reg [2:0] page=0;
 reg [7:0] col=0,buffer=8'hxx;
 reg dummy=1,contrast_pending=0,display_on=0;
 reg [7:0] drive=8'hzz;
 integer reads=0,writes=0,clear_writes=0,commands=0;
 time wr_start=0,rd_start=0,last_wr=0,last_rd=0,last_change=0,release_at=0;
 time last_wr_end=0,last_rd_end=0;
 reg [7:0] expected_init[0:7];
 initial begin
  expected_init[0]=8'ha2;expected_init[1]=8'ha0;expected_init[2]=8'hc8;
  expected_init[3]=8'h2f;expected_init[4]=8'h24;expected_init[5]=8'h81;
  expected_init[6]=8'h1c;expected_init[7]=8'h40;
 end
 reg [7:0] held_data;
 reg held_a0;
 assign data=drive;
 always @(data or a0) last_change=$time;
 always @(negedge host_oe) release_at=$time;
 always @(negedge rst_n) begin
  page=0;col=0;buffer=8'hxx;dummy=1;contrast_pending=0;display_on=0;
 end
 always @(negedge wr_n) if(rst_n && !cs_n) begin
  if(!rd_n || !host_oe) $fatal(1,"Invalid write ownership");
  if($time-last_change<52) $fatal(1,"Write setup below 52 ns");
  if(last_wr && $time-last_wr<312) $fatal(1,"Write cycle below 312 ns");
  if(last_wr && $time-last_wr_end<104) $fatal(1,"Write high below 104 ns");
  wr_start=$time;last_wr=$time;held_data=data;held_a0=a0;
 end
 always @(posedge wr_n) if(rst_n && !cs_n) begin
  if($time-wr_start<104) $fatal(1,"Write low below 104 ns");
  if(data!==held_data || a0!==held_a0) $fatal(1,"Data changed during write");
  last_wr_end=$time;
  if(a0) begin
   if(col>131) $fatal(1,"Column out of range");
   ram[page*132+col]=data;writes=writes+1;
   if(!display_on) begin
    if(data!==0) $fatal(1,"Clear data not zero");
    clear_writes=clear_writes+1;
   end
   col=col==131 ? 0 : col+1;
  end else begin
   if(commands<8 && data!==expected_init[commands]) $fatal(1,"Initialization sequence mismatch");
   commands=commands+1;
   if(contrast_pending) contrast_pending=0;
   else if(data==8'h81) contrast_pending=1;
   else if(data==8'haf) begin
    if(clear_writes!=1056) $fatal(1,"Incomplete clear before display on");
    display_on=1;
   end
   else if(data[7:4]==4'hb) begin page=data[2:0];dummy=1;end
   else if(data[7:4]==4'h1) begin col[7:4]=data[3:0];dummy=1;end
   else if(data[7:4]==4'h0) begin col[3:0]=data[3:0];dummy=1;end
  end
 end
 always @(negedge rd_n) if(rst_n && !cs_n) begin
  if(!wr_n || host_oe || !a0) $fatal(1,"Invalid read ownership");
  if($time-release_at<400) $fatal(1,"Insufficient high-Z turnaround");
  if(last_rd && $time-last_rd<312) $fatal(1,"Read cycle below 312 ns");
  if(last_rd && $time-last_rd_end<104) $fatal(1,"Read high below 104 ns");
  rd_start=$time;last_rd=$time;
  drive<=#70 (dummy ? 8'hxx : buffer);
 end
 always @(posedge rd_n) if(rst_n && !cs_n) begin
  if($time-rd_start<182) $fatal(1,"Read low below 182 ns");
  last_rd_end=$time;
  buffer=ram[page*132+col];col=col==131 ? 0 : col+1;
  dummy=0;reads=reads+1;drive<=#50 8'hzz;
 end
 always @(posedge host_oe) if(drive!==8'hzz) $fatal(1,"Bus contention");
endmodule
