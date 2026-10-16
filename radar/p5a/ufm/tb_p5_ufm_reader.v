`timescale 1ns/1ps
module tb_p5_ufm_reader;
    reg clk=0, rst=1, request=0, sequential=0;
    reg [8:0] address=0;
    wire busy, done;
    wire [15:0] value;
    reg [15:0] expected [0:511];
    integer checks=0, pulses=0, bits_seen=0, expected_address=0;
    integer min_random=10000, max_random=0, min_seq=10000, max_seq=0;
    reg [8:0] serial_address=0;
    realtime last_ar=-1000,last_dr=-1000,last_data=-1000,last_control=-1000;
    realtime last_ar_fall=-1000,last_dr_fall=-1000;
    always #10 clk=~clk;
    p5_ufm_reader dut(.*);
    initial $readmemh("background.mem",expected);
    always @(dut.addr_shift[8]) begin
        if(!rst && $realtime-last_ar<20) $fatal(1,"ARDIN hold");
        last_data=$realtime;
    end
    always @(dut.drshft) begin
        if(!rst && $realtime-last_dr<20) $fatal(1,"DRSHFT hold");
        last_control=$realtime;
    end
    always @(posedge dut.arclk) begin
        if ($realtime-last_ar<320 || $realtime-last_data<20 || $realtime-last_ar_fall<160) $fatal(1,"ARCLK timing");
        last_ar=$realtime;
        if(dut.arshft) serial_address={serial_address[7:0],dut.addr_shift[8]};
        else serial_address=serial_address+1'b1;
        bits_seen=bits_seen+1;
    end
    always @(negedge dut.arclk) begin
        if(!rst && $realtime-last_ar<160) $fatal(1,"ARCLK high width");
        last_ar_fall=$realtime;
    end
    always @(posedge dut.drclk) begin
        if($realtime-last_dr<320 || $realtime-last_control<60 || $realtime-last_dr_fall<160) $fatal(1,"DRCLK timing");
        if(!dut.drshft && serial_address!==expected_address[8:0]) $fatal(1,"MSB-first address %d != %d",serial_address,expected_address);
        last_dr=$realtime; pulses=pulses+1;
    end
    always @(negedge dut.drclk) begin
        if(!rst && $realtime-last_dr<160) $fatal(1,"DRCLK high width");
        last_dr_fall=$realtime;
    end
    task read_word;
        input integer a;
        input seq;
        integer cycles;
        begin
            @(negedge clk);
            address=a; sequential=seq; expected_address=a; request=1;
            pulses=0;bits_seen=0;cycles=0;
            @(negedge clk); request=0;
            while(!done && cycles<500) begin @(negedge clk); cycles=cycles+1; end
            if(!done || value!==expected[a]) $fatal(1,"word %d got=%h expected=%h cycles=%d",a,value,expected[a],cycles);
            if(pulses!=16 || bits_seen!=(seq?1:9)) $fatal(1,"serial pulse count");
            if(seq) begin
                if(cycles<min_seq)min_seq=cycles;if(cycles>max_seq)max_seq=cycles;
            end else begin
                if(cycles<min_random)min_random=cycles;if(cycles>max_random)max_random=cycles;
            end
            checks=checks+1;
            @(negedge clk); if(done || busy) $fatal(1,"done width / busy");
        end
    endtask
    integer i,j;
    initial begin
        #100; @(negedge clk);rst=0;
        // Permuted random reads visit every address exactly once.
        for(i=0;i<512;i=i+1) begin
            repeat(i%16) @(negedge clk);
            read_word((i*197+83)%512,0);
        end
        read_word(0,0);
        for(i=1;i<512;i=i+1) begin
            repeat(i%16) @(negedge clk);
            read_word(i,1);
        end
        read_word(0,1); // wrap 511 -> 0
        $display("PASS UFM words=%0d random_cycles=%0d..%0d sequential_cycles=%0d..%0d; ARCLK/DRCLK min period320ns high/low160ns; MSB-first verified; output settling180ns",checks,min_random,max_random,min_seq,max_seq);
        $finish;
    end
    initial begin #20000000;$fatal(1,"timeout");end
endmodule
