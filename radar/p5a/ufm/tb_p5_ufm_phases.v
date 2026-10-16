`timescale 1ns/1ps
module tb_p5_ufm_phases;
    reg clk=0,rst=1,request=0,sequential=0;
    reg [8:0] address=0;
    wire busy,done;
    wire [15:0] value;
    reg [15:0] expected[0:511];
    integer phase_case,operation,cycles,expected_address;
    integer mask_random=0,mask_increment=0,checks=0;
    realtime address_change=-1000,arshft_change=-1000,drshft_change=-1000;
    realtime ar_rise=-1000,dr_rise=-1000,ar_fall=-1000,dr_fall=-1000;
    realtime min_ardin_setup=100000,min_arshft_setup=100000,min_drshft_setup=100000;
    realtime min_ardin_hold=100000,min_arshft_hold=100000,min_drshft_hold=100000;
    always #10 clk=~clk;
    p5_ufm_reader dut(.*);
    initial $readmemh("background.mem",expected);
    always @(dut.addr_shift[8]) begin
        if(!rst && $realtime-ar_rise<20) $fatal(1,"ARDIN hold");
        if(!rst && $realtime-ar_rise<min_ardin_hold)min_ardin_hold=$realtime-ar_rise;
        address_change=$realtime;
    end
    always @(dut.arshft) begin
        if(!rst && $realtime-ar_rise<20) $fatal(1,"ARSHFT hold");
        if(!rst && $realtime-ar_rise<min_arshft_hold)min_arshft_hold=$realtime-ar_rise;
        arshft_change=$realtime;
    end
    always @(dut.drshft) begin
        if(!rst && $realtime-dr_rise<20) $fatal(1,"DRSHFT hold");
        if(!rst && $realtime-dr_rise<min_drshft_hold)min_drshft_hold=$realtime-dr_rise;
        drshft_change=$realtime;
    end
    always @(posedge dut.arclk) begin
        if($realtime-ar_rise<320 || $realtime-ar_fall<160) $fatal(1,"AR clock");
        if($realtime-address_change<20 || $realtime-arshft_change<20) $fatal(1,"AR setup");
        if($realtime-address_change<min_ardin_setup)min_ardin_setup=$realtime-address_change;
        if($realtime-arshft_change<min_arshft_setup)min_arshft_setup=$realtime-arshft_change;
        ar_rise=$realtime;
    end
    always @(negedge dut.arclk) begin
        if(!rst && $realtime-ar_rise<160)$fatal(1,"AR high");ar_fall=$realtime;
    end
    always @(posedge dut.drclk) begin
        if($realtime-dr_rise<320 || $realtime-dr_fall<160) $fatal(1,"DR clock");
        if($realtime-drshft_change<60)$fatal(1,"DRSHFT setup");
        if($realtime-drshft_change<min_drshft_setup)min_drshft_setup=$realtime-drshft_change;
        if(!dut.drshft && dut.model_address!==expected_address[8:0])$fatal(1,"address");
        dr_rise=$realtime;
    end
    always @(negedge dut.drclk) begin
        if(!rst && $realtime-dr_rise<160)$fatal(1,"DR high");dr_fall=$realtime;
    end
    task read_phase;
        input integer target_phase;
        input seq;
        begin
            @(negedge clk);
            while(dut.phase != target_phase) @(negedge clk);
            if(busy)$fatal(1,"busy before request");
            request=1;sequential=seq;
            if(seq) begin expected_address=(expected_address+1)%512;mask_increment=mask_increment|(1<<target_phase);end
            else begin
                // Force a real first-ARDIN transition for every launch phase.
                expected_address=(value[15] ? 0 : 256) | (target_phase*13);
                address=expected_address;mask_random=mask_random|(1<<target_phase);
            end
            @(negedge clk);request=0;cycles=0;
            while(!done && cycles<500)begin @(negedge clk);cycles=cycles+1;end
            if(!done || value!==expected[expected_address])$fatal(1,"phase=%d seq=%d value=%h expected=%h",target_phase,seq,value,expected[expected_address]);
            checks=checks+1;
            @(negedge clk);
            if(done || busy)$fatal(1,"completion");
        end
    endtask
    initial begin
        #100;@(negedge clk);rst=0;
        for(phase_case=0;phase_case<16;phase_case=phase_case+1)begin
            read_phase(phase_case,0);read_phase(phase_case,1);
        end
        if(mask_random!=65535 || mask_increment!=65535)$fatal(1,"phase coverage");
        $display("PASS UFM shared 16-phase random+increment coverage=%h/%h words=%0d",mask_random,mask_increment,checks);
        $display("minimum setup ns ARDIN=%0.0f ARSHFT=%0.0f DRSHFT=%0.0f; hold ns ARDIN=%0.0f ARSHFT=%0.0f DRSHFT=%0.0f",min_ardin_setup,min_arshft_setup,min_drshft_setup,min_ardin_hold,min_arshft_hold,min_drshft_hold);
        $finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule
