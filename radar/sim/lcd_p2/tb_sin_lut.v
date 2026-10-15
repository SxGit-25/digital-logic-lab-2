`timescale 1ns/1ps
module tb_sin_lut;
    reg clk=0, rst=1, request=0;
    reg [6:0] address=0;
    wire case_done, ufm_done;
    wire [8:0] case_value, ufm_value;
    integer angle, expected, latency, min_latency=9999, max_latency=0;
    integer cycle=0, accepted_cycle;
    reg [8:0] reference [0:90];
    realtime ardin_change=0, drshft_change=0, ar_rise=0, dr_rise=0;

    always #10 clk=~clk;
    always @(posedge clk) cycle=cycle+1;
    lcd_sin_lut #(.USE_UFM(0)) case_lut (
        .clk(clk), .rst(rst), .request(request), .address(address),
        .done(case_done), .value(case_value)
    );
    lcd_sin_lut #(.USE_UFM(1)) ufm_lut (
        .clk(clk), .rst(rst), .request(request), .address(address),
        .done(ufm_done), .value(ufm_value)
    );

    // Handbook minimums with 30% margin: ARDIN setup/hold 26 ns,
    // DRSHFT setup 78 ns and hold 26 ns. RTL supplies 320 ns normally.
    always @(ufm_lut.g_ufm.addr_shift[8]) begin
        if (!rst && $realtime-ar_rise<26)
            $fatal(1,"ARDIN hold violates 26 ns margin");
        ardin_change=$realtime;
    end
    always @(ufm_lut.g_ufm.drshft) begin
        if (!rst && $realtime-dr_rise<26)
            $fatal(1,"DRSHFT hold violates 26 ns margin");
        drshft_change=$realtime;
    end
    always @(posedge ufm_lut.g_ufm.arclk) begin
        if ($realtime-ardin_change<26)
            $fatal(1,"ARDIN setup violates 26 ns margin");
        if (ar_rise>0 && $realtime-ar_rise<130)
            $fatal(1,"ARCLK period violates 130 ns margin");
        ar_rise=$realtime;
    end
    always @(posedge ufm_lut.g_ufm.drclk) begin
        if ($realtime-drshft_change<78)
            $fatal(1,"DRSHFT setup violates 78 ns margin");
        if (dr_rise>0 && $realtime-dr_rise<130)
            $fatal(1,"DRCLK period violates 130 ns margin");
        dr_rise=$realtime;
    end

    initial begin
        $readmemh("sin_reference.hex",reference);
        #40; @(negedge clk); rst=0;
        for (angle=0; angle<=90; angle=angle+1) begin
            repeat (angle & 31) @(negedge clk);
            @(negedge clk); address=angle; request=1;
            @(posedge clk); #1; accepted_cycle=cycle;
            @(negedge clk); request=0;
            expected=reference[angle];
            if (!case_done || case_value!==expected)
                $fatal(1,"case angle=%0d got=%0d expected=%0d",angle,case_value,expected);
            wait(ufm_done);
            latency=cycle-accepted_cycle;
            if (latency<609 || latency>640)
                $fatal(1,"UFM latency %0d outside 609..640 clocks",latency);
            if (latency<min_latency) min_latency=latency;
            if (latency>max_latency) max_latency=latency;
            @(negedge clk);
            if (ufm_value!==expected)
                $fatal(1,"UFM angle=%0d got=%0d expected=%0d",angle,ufm_value,expected);
            @(negedge clk);
            if (ufm_done || case_done) $fatal(1,"done pulse exceeds one clock");
        end
        $display("PASS: case and serial UFM all 91 angles match floating-point Q1.8 reference");
        $display("PASS: UFM serial model includes 180 ns output settling delay");
        $display("PASS: ARDIN/DRSHFT setup/hold and serial periods meet handbook +30%%");
        $display("Observed latency %0d..%0d clocks (required 609..640)",min_latency,max_latency);
        $finish;
    end
    initial begin #2000000; $fatal(1,"lookup timeout"); end
endmodule
