`timescale 1ns/1ps
module tb_display_shared;
    reg clk=0; always #10 clk=~clk;
    reg rst=1,enable=1,tick=0,blink=0,valid=0;
    reg [1:0] state=0,phase=0;
    reg [11:0] angle=0;
    reg [15:0] distance=0;
    reg [14:0] levels=0;
    reg [4:0] hv=0,hs=0;
    wire [6:0] seg;
    wire [7:0] cat,row,red,green;
    wire [2:0] idx;
    wire [31:0] digits;
    wire [23:0] colors;
    radar_display_shared dut(clk,rst,enable,tick,phase,state,blink,angle,
        distance,valid,levels[2:0],levels[5:3],levels[8:6],levels[11:9],
        levels[14:12],hv,hs,seg,cat,row,red,green,idx);
    display_compose #(.SUPPORT_CONTINUOUS(1)) oracle(
        .system_state(state),.blink_2hz(blink),.angle_idx(3'd0),
        .distance_bcd(distance),.current_valid(valid),.hist_level0(levels[2:0]),
        .hist_level1(levels[5:3]),.hist_level2(levels[8:6]),
        .hist_level3(levels[11:9]),.hist_level4(levels[14:12]),
        .hist_valid(hv),.hist_seen(hs),.row_idx(idx),.digit_codes(digits),
        .row_colors(colors),.continuous_mode(1'b1),.continuous_angle_bcd(angle));
    function [6:0] decode;
        input [3:0] c;
        begin
            case(c)
                0:decode=126;1:decode=48;2:decode=109;3:decode=121;
                4:decode=51;5:decode=91;6:decode=95;7:decode=112;
                8:decode=127;9:decode=123;10:decode=1;default:decode=0;
            endcase
        end
    endfunction
    integer st,bl,p,l,seen,v,d,n,i,checks=0;
    reg [7:0] er,eg;
    reg [2:0] c;
    task check_frame;
        begin
            for(n=0;n<8;n=n+1) begin
                @(negedge clk);tick=1;
                @(negedge clk);tick=0;
                if(cat!==255 || row!==255) $fatal(1,"Selectors not blanked");
                @(negedge clk);
                if(cat!==255 || row!==255) $fatal(1,"Data changed without blank");
                @(negedge clk);
                er=0;eg=0;
                for(i=0;i<8;i=i+1) begin
                    c=colors[i*3+:3];
                    case(c)
                        1:eg[i]=1;
                        2:begin er[i]=(phase==0);eg[i]=(phase!=0);end
                        3:begin er[i]=(phase<2);eg[i]=(phase>=2);end
                        4:begin er[i]=(phase<3);eg[i]=(phase==3);end
                        5:er[i]=1;
                    endcase
                end
                if(seg!==decode(digits[idx*4+:4]) || red!==er || green!==eg ||
                   cat!==~(8'b1<<idx) || row!==cat)
                    $fatal(1,"Oracle mismatch state=%d phase=%d idx=%d levels=%h seen=%h valid=%h",state,phase,idx,levels,hs,hv);
                checks=checks+1;
            end
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);rst=0;
        // All states, blink and PWM phases; each ray independently exercises
        // all 8 level encodings and the four seen/valid combinations.
        for(st=0;st<4;st=st+1) for(bl=0;bl<2;bl=bl+1)
        for(p=0;p<4;p=p+1) for(l=0;l<8;l=l+1)
        for(seen=0;seen<4;seen=seen+1) begin
            state=st;blink=bl;phase=p;valid=seen[0];
            hs={5{seen[1]}};hv={5{seen[0]}};
            levels={3'((l+4)&7),3'((l+3)&7),3'((l+2)&7),3'((l+1)&7),3'(l)};
            distance=16'h1234;angle=12'h180;check_frame;
        end
        // Every BCD nibble encoding including dash/blank/unused codes.
        state=3;valid=1;
        for(d=0;d<16;d=d+1) begin
            distance={4{d[3:0]}};angle={3{d[3:0]}};check_frame;
        end
        for(p=0;p<4;p=p+1) for(seen=0;seen<32;seen=seen+1)
        for(v=0;v<32;v=v+1) begin
            phase=p;hs=seen;hv=v;
            levels={3'd5,3'd4,3'd3,3'd2,3'd1};check_frame;
        end
        enable=0;@(negedge clk);
        if(cat!==255 || row!==255 || seg!==0 || red!==0 || green!==0)
            $fatal(1,"Disable gating");
        $display("PASS shared_display oracle_checks=%0d frames=500Hz per_LED_PWM=125Hz blank=40ns",checks);
        $finish;
    end
endmodule
