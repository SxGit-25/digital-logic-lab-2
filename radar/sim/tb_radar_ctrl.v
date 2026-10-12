`timescale 1ns/1ps

module tb_radar_ctrl;
    reg clk = 1'b0;
    reg rst = 1'b1;
    reg system_on = 1'b0;
    reg angle_applied = 1'b0;
    reg measure_busy = 1'b0;
    reg measure_done = 1'b0;
    reg [11:0] distance_mm = 12'd0;
    reg distance_valid = 1'b0;
    wire [1:0] state;
    wire servo_enable;
    wire [2:0] angle_idx;
    wire measure_start;
    wire measure_cancel;
    wire [2:0] sample_idx;
    wire [11:0] current_distance;
    wire current_valid;
    wire [2:0] current_level;
    wire [2:0] h0, h1, h2, h3, h4;
    wire [4:0] hist_valid;
    wire [4:0] hist_seen;
    integer sample_count = 0;
    reg [2:0] expected_idx [0:8];
    reg [11:0] test_distance [0:8];

    always #5 clk = ~clk;

    radar_ctrl #(
        .SELF_TEST_MS(2), .STANDBY_MS(2), .SLOT_MS(8), .SETTLE_MS(1)
    ) dut (
        .clk(clk), .rst(rst), .tick_ms(1'b1), .system_on(system_on),
        .angle_applied(angle_applied), .measure_busy(measure_busy),
        .measure_done(measure_done), .distance_mm(distance_mm),
        .distance_valid(distance_valid), .system_state(state),
        .servo_enable(servo_enable), .angle_idx(angle_idx),
        .measure_start(measure_start), .measure_cancel(measure_cancel),
        .sample_idx(sample_idx), .current_distance(current_distance),
        .current_valid(current_valid), .current_level(current_level),
        .hist_level0(h0), .hist_level1(h1), .hist_level2(h2),
        .hist_level3(h3), .hist_level4(h4), .hist_valid(hist_valid),
        .hist_seen(hist_seen)
    );

    always @(posedge clk) begin
        angle_applied <= 1'b0;
        measure_done  <= 1'b0;
        if ((state == 2'd3) && (dut.phase == 3'd0))
            angle_applied <= 1'b1;

        if (measure_start) begin
            if (sample_idx !== expected_idx[sample_count]) begin
                $display("FAIL scan order at %0d: got %0d expected %0d",
                         sample_count, sample_idx, expected_idx[sample_count]);
                $fatal(1);
            end
            distance_mm    <= test_distance[sample_count];
            distance_valid <= 1'b1;
            measure_done   <= 1'b1;
            sample_count   <= sample_count + 1;
        end
    end

    initial begin
        expected_idx[0]=0; expected_idx[1]=1; expected_idx[2]=2;
        expected_idx[3]=3; expected_idx[4]=4; expected_idx[5]=3;
        expected_idx[6]=2; expected_idx[7]=1; expected_idx[8]=0;
        test_distance[0]=199; test_distance[1]=200; test_distance[2]=399;
        test_distance[3]=400; test_distance[4]=599; test_distance[5]=600;
        test_distance[6]=799; test_distance[7]=800; test_distance[8]=1000;

        repeat (3) @(posedge clk);
        rst <= 1'b0;
        system_on <= 1'b1;
        wait (sample_count == 9);
        repeat (2) @(posedge clk);

        if (h0 != 3'd1 || h1 != 3'd1 || h2 != 3'd2 ||
            h3 != 3'd2 || h4 != 3'd3) begin
            $display("FAIL level/history boundaries h=%0d,%0d,%0d,%0d,%0d", h0,h1,h2,h3,h4);
            $fatal(1);
        end
        if (hist_seen != 5'b11111 || hist_valid != 5'b11111) begin
            $display("FAIL history valid/seen flags");
            $fatal(1);
        end

        system_on <= 1'b0;
        @(posedge clk); #1;
        if (state != 2'd0 || hist_seen != 5'b0 || servo_enable) begin
            $display("FAIL off-state cleanup");
            $fatal(1);
        end
        $display("PASS tb_radar_ctrl");
        $finish;
    end
endmodule
