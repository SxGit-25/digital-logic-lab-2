`timescale 1ns/1ps
module compare_counters #(parameter N=1, HZ=1000000)(input clk,rst,enable,tick,sw);
    wire [2:0] time_new,time_old;
    wire switch_new,switch_old;
    wire [14:0] seg_new,seg_old;
    wire [26:0] matrix_new,matrix_old;
    timebase #(.CLK_HZ(HZ)) t(clk,rst,time_new[0],time_new[1],time_new[2]);
    timebase_baseline #(.CLK_HZ(HZ)) tb(clk,rst,time_old[0],time_old[1],time_old[2]);
    switch_filter #(.FILTER_MS(N)) s(clk,rst,tick,sw,switch_new);
    switch_filter_baseline #(.FILTER_MS(N)) sb(clk,rst,tick,sw,switch_old);
    seg_scan #(.DIGIT_US(N)) d(clk,rst,tick,enable,32'h98765432,seg_new[14:8],seg_new[7:0]);
    seg_scan_baseline #(.DIGIT_US(N)) db(clk,rst,tick,enable,32'h98765432,seg_old[14:8],seg_old[7:0]);
    matrix_scan #(.PHASE_US(N)) m(clk,rst,tick,enable,24'hB1A688,matrix_new[26:24],matrix_new[23:16],matrix_new[15:8],matrix_new[7:0]);
    matrix_scan_baseline #(.PHASE_US(N)) mb(clk,rst,tick,enable,24'hB1A688,matrix_old[26:24],matrix_old[23:16],matrix_old[15:8],matrix_old[7:0]);
    always @(posedge clk) begin
      #1;
      if({time_new,switch_new,seg_new,matrix_new} !== {time_old,switch_old,seg_old,matrix_old})
        $fatal(1,"baseline mismatch N=%0d HZ=%0d at %0t",N,HZ,$time);
    end
endmodule
module compare_ultrasonic #(parameter TRIG=1, TIMEOUT=1)(input clk,rst,start,cancel,echo);
    wire [15:0] actual,expected;
    ultrasonic #(.TRIG_US(TRIG),.TIMEOUT_US(TIMEOUT)) u
      (clk,rst,1'b1,start,cancel,echo,actual[15],actual[14],actual[13],actual[12:1],actual[0], , );
    ultrasonic_baseline #(.TRIG_US(TRIG),.TIMEOUT_US(TIMEOUT)) ub
      (clk,rst,1'b1,start,cancel,echo,expected[15],expected[14],expected[13],expected[12:1],expected[0]);
    always @(posedge clk) begin
      #1;
      if(actual !== expected) $fatal(1,"ultrasonic baseline mismatch TRIG=%0d TIMEOUT=%0d at %0t",TRIG,TIMEOUT,$time);
    end
endmodule
module tb_counter_equivalence;
    reg clk=0,rst=1,enable=0,tick=0,sw=0;
    reg start=0,cancel=0,echo=0;
    integer i;
    always #5 clk=~clk;
    compare_counters #(1,1000000) edge_case(clk,rst,enable,tick,sw);
    compare_counters #(3,3000000) non_power_two(clk,rst,enable,tick,sw);
    compare_counters #(250,50000000) normal_case(clk,rst,enable,tick,sw);
    compare_counters #(257,65000000) above_power_two(clk,rst,enable,tick,sw);
    compare_ultrasonic #(1,1) ultra_min(clk,rst,start,cancel,echo);
    compare_ultrasonic #(16,256) ultra_power_two(clk,rst,start,cancel,echo);
    compare_ultrasonic #(17,257) ultra_above_power_two(clk,rst,start,cancel,echo);
    compare_ultrasonic #(15,30000) ultra_normal(clk,rst,start,cancel,echo);
    initial begin
      repeat(3) @(negedge clk);
      rst=0; enable=1;
      // More than two blink half-periods at 1 MHz; full scan and debounce
      // rollover coverage at all parameter sets, including sparse tick enable.
      for(i=0;i<610000;i=i+1) begin
        @(negedge clk);
        tick=(i%3)!=0;
        sw=(i%2300)<1100;
        enable=(i%3100)>20;
        start=(i%40000)==0;
        // Alternate a valid echo, no echo, stuck-high echo, and cancellation.
        case((i/40000)%4)
          0: echo=(i%40000)>=50 && (i%40000)<1050;
          1: echo=0;
          2: echo=(i%40000)>=50;
          3: echo=(i%40000)>=50 && (i%40000)<250;
        endcase
        cancel=((i/40000)%4)==3 && (i%40000)==150;
      end
      rst=1;
      repeat(3) @(negedge clk);
      $display("PASS tb_counter_equivalence: 610000 cycles, N=1/3/250/257 HZ=1/3/50/65MHz, ultrasonic TIMEOUT=1/256/257/30000");
      $finish;
    end
endmodule
