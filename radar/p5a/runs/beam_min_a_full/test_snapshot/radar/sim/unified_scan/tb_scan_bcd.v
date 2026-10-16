`timescale 1ns/1ps
module tb_scan_bcd;
    reg clk=0;always #5 clk=~clk;
    reg rst=1;
    reg done=0,busy=0,valid_in=1;
    reg [15:0] bcd_in=0;
    wire start,valid,commit;
    wire [15:0] bcd_out;
    wire [11:0] mm_out;
    wire [2:0] level,idx,h0,h1,h2,h3,h4;
    wire [4:0] seen,hvalid;
    reg [15:0] values[0:10];
    integer levels[0:10];
    integer i,history_level;
    radar_unified_scan #(.SELF_TEST_MS(1),.STANDBY_MS(1),.SLOT_MS(64),.SETTLE_MS(50),
        .FAST_STEP_US(1),.DISTANCE_IS_BCD(1)) dut(
        .clk(clk),.rst(rst),.tick_us(1'b1),.tick_ms(1'b1),.enable(1'b1),.continuous_mode(1'b0),
        .measure_busy(busy),.measure_done(done),.distance_mm(12'd4095),.distance_valid(valid_in),
        .distance_bcd(bcd_in),.current_bcd(bcd_out),.measure_start(start),.current_distance(mm_out),
        .current_valid(valid),.current_level(level),.sample_idx(idx),.sample_event(commit),
        .hist_level0(h0),.hist_level1(h1),.hist_level2(h2),.hist_level3(h3),.hist_level4(h4),
        .hist_valid(hvalid),.hist_seen(seen));
    initial begin
        values[0]=16'h0199;levels[0]=5;
        values[1]=16'h0200;levels[1]=4;
        values[2]=16'h0399;levels[2]=4;
        values[3]=16'h0400;levels[3]=3;
        values[4]=16'h0599;levels[4]=3;
        values[5]=16'h0600;levels[5]=2;
        values[6]=16'h0799;levels[6]=2;
        values[7]=16'h0800;levels[7]=1;
        values[8]=16'h1200;levels[8]=1;
        values[9]=16'h4000;levels[9]=1;
        values[10]=16'h0000;levels[10]=5;
        repeat(3) @(negedge clk);rst=0;
        for(i=0;i<11;i=i+1) begin
            @(posedge start);
            @(negedge clk);busy=1;
            repeat(3) @(negedge clk);
            // Model the ultrasonic committed output, which holds throughout
            // echo counting and changes only when measure_done is asserted.
            busy=0;bcd_in=values[i];valid_in=(i!=10);done=1;
            @(negedge clk);done=0;
            #1;
            case(idx) 0:history_level=h0;1:history_level=h1;2:history_level=h2;3:history_level=h3;4:history_level=h4;endcase
            if(bcd_out!==values[i] || mm_out!==0 || level!==(i==10?0:levels[i]) ||
                valid!==(i!=10) || !seen[idx] || hvalid[idx]!==(i!=10) || history_level!=(i==10?0:levels[i]))
                $fatal(1,"BCD mode value=%h current_bcd=%h mm=%0d level=%0d hist=%0d valid=%b",values[i],bcd_out,mm_out,level,history_level,valid);
        end
        $display("PASS tb_scan_bcd isolated flag1 BCD thresholds 0199/0200/0399/0400/0599/0600/0799/0800/1200/4000 invalid/history; binary output zero");
        $finish;
    end
    initial begin #20000;$fatal(1,"BCD watchdog");end
endmodule
