`timescale 1ns/1ps
// One 91-word quadrant table. Q1.8: sin(90 degrees) = 256.
// Requests while busy are ignored. done is a one-clock completion pulse.
module lcd_sin_lut #(
    parameter USE_UFM = 0
)(
    input wire clk,
    input wire rst,
    input wire request,
    input wire [6:0] address,
    output reg done,
    output reg [8:0] value
);
    function [8:0] sin_lookup;
        input [6:0] a;
        begin
            case (a)
        // BEGIN GENERATED SIN TABLE
            7'd0: sin_lookup = 9'd0;
            7'd1: sin_lookup = 9'd4;
            7'd2: sin_lookup = 9'd9;
            7'd3: sin_lookup = 9'd13;
            7'd4: sin_lookup = 9'd18;
            7'd5: sin_lookup = 9'd22;
            7'd6: sin_lookup = 9'd27;
            7'd7: sin_lookup = 9'd31;
            7'd8: sin_lookup = 9'd36;
            7'd9: sin_lookup = 9'd40;
            7'd10: sin_lookup = 9'd44;
            7'd11: sin_lookup = 9'd49;
            7'd12: sin_lookup = 9'd53;
            7'd13: sin_lookup = 9'd58;
            7'd14: sin_lookup = 9'd62;
            7'd15: sin_lookup = 9'd66;
            7'd16: sin_lookup = 9'd71;
            7'd17: sin_lookup = 9'd75;
            7'd18: sin_lookup = 9'd79;
            7'd19: sin_lookup = 9'd83;
            7'd20: sin_lookup = 9'd88;
            7'd21: sin_lookup = 9'd92;
            7'd22: sin_lookup = 9'd96;
            7'd23: sin_lookup = 9'd100;
            7'd24: sin_lookup = 9'd104;
            7'd25: sin_lookup = 9'd108;
            7'd26: sin_lookup = 9'd112;
            7'd27: sin_lookup = 9'd116;
            7'd28: sin_lookup = 9'd120;
            7'd29: sin_lookup = 9'd124;
            7'd30: sin_lookup = 9'd128;
            7'd31: sin_lookup = 9'd132;
            7'd32: sin_lookup = 9'd136;
            7'd33: sin_lookup = 9'd139;
            7'd34: sin_lookup = 9'd143;
            7'd35: sin_lookup = 9'd147;
            7'd36: sin_lookup = 9'd150;
            7'd37: sin_lookup = 9'd154;
            7'd38: sin_lookup = 9'd158;
            7'd39: sin_lookup = 9'd161;
            7'd40: sin_lookup = 9'd165;
            7'd41: sin_lookup = 9'd168;
            7'd42: sin_lookup = 9'd171;
            7'd43: sin_lookup = 9'd175;
            7'd44: sin_lookup = 9'd178;
            7'd45: sin_lookup = 9'd181;
            7'd46: sin_lookup = 9'd184;
            7'd47: sin_lookup = 9'd187;
            7'd48: sin_lookup = 9'd190;
            7'd49: sin_lookup = 9'd193;
            7'd50: sin_lookup = 9'd196;
            7'd51: sin_lookup = 9'd199;
            7'd52: sin_lookup = 9'd202;
            7'd53: sin_lookup = 9'd204;
            7'd54: sin_lookup = 9'd207;
            7'd55: sin_lookup = 9'd210;
            7'd56: sin_lookup = 9'd212;
            7'd57: sin_lookup = 9'd215;
            7'd58: sin_lookup = 9'd217;
            7'd59: sin_lookup = 9'd219;
            7'd60: sin_lookup = 9'd222;
            7'd61: sin_lookup = 9'd224;
            7'd62: sin_lookup = 9'd226;
            7'd63: sin_lookup = 9'd228;
            7'd64: sin_lookup = 9'd230;
            7'd65: sin_lookup = 9'd232;
            7'd66: sin_lookup = 9'd234;
            7'd67: sin_lookup = 9'd236;
            7'd68: sin_lookup = 9'd237;
            7'd69: sin_lookup = 9'd239;
            7'd70: sin_lookup = 9'd241;
            7'd71: sin_lookup = 9'd242;
            7'd72: sin_lookup = 9'd243;
            7'd73: sin_lookup = 9'd245;
            7'd74: sin_lookup = 9'd246;
            7'd75: sin_lookup = 9'd247;
            7'd76: sin_lookup = 9'd248;
            7'd77: sin_lookup = 9'd249;
            7'd78: sin_lookup = 9'd250;
            7'd79: sin_lookup = 9'd251;
            7'd80: sin_lookup = 9'd252;
            7'd81: sin_lookup = 9'd253;
            7'd82: sin_lookup = 9'd254;
            7'd83: sin_lookup = 9'd254;
            7'd84: sin_lookup = 9'd255;
            7'd85: sin_lookup = 9'd255;
            7'd86: sin_lookup = 9'd255;
            7'd87: sin_lookup = 9'd256;
            7'd88: sin_lookup = 9'd256;
            7'd89: sin_lookup = 9'd256;
            7'd90: sin_lookup = 9'd256;
        // END GENERATED SIN TABLE
                default: sin_lookup = 9'd0;
            endcase
        end
    endfunction

    generate if (USE_UFM == 0) begin : g_case
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                done <= 1'b0;
                value <= 9'd0;
            end else begin
                done <= request;
                if (request) value <= sin_lookup(address);
            end
        end
    end else begin : g_ufm
        // Serial clock period 32*20 ns = 640 ns; both pulse widths 320 ns.
        // Address is shifted MSB-first, then the flash data is parallel-loaded.
        // Only the nine MSBs are needed; the seven LSBs are MIF padding.
        localparam IDLE=0, ADDR=1, WAIT_ACCESS=2, LOAD=3, SHIFT=4, ALIGN=5;
        reg [2:0] state;
        reg [4:0] phase;
        reg [3:0] bit_count;
        reg [8:0] addr_shift;
        reg arclk, drclk, drshft;
        wire serial_data;
`ifdef ALTERA_RESERVED_QIS
`define LCD_SIN_LUT_HARDWARE
`elsif SYNTHESIS
`define LCD_SIN_LUT_HARDWARE
`endif
`ifdef LCD_SIN_LUT_HARDWARE
        altufm_none #(
            .width_ufm_address(9),
            .lpm_file("lcd_sin_q8.mif"),
            .port_arclkena("PORT_UNUSED"),
            .port_drclkena("PORT_UNUSED")
        ) flash (
            .arclk(arclk), .arclkena(1'b1),
            .ardin(addr_shift[8]), .arshft(1'b1),
            .drclk(drclk), .drclkena(1'b1),
            .drdin(1'b0), .drshft(drshft),
            .erase(1'b0), .program(1'b0), .oscena(1'b0),
            .drdout(serial_data), .busy(), .osc(), .rtpbusy()
        );
`else
        // The same 9-bit address/16-bit data serial protocol as maxii_ufm.
        // Inject 180 ns output settling delay to stress the sampling margin.
        reg [8:0] model_address = 0;
        reg [15:0] model_data = 0;
        always @(posedge arclk)
            model_address <= {model_address[7:0], addr_shift[8]};
        always @(posedge drclk)
            if (!drshft)
                model_data <= #180 {sin_lookup(model_address[6:0]), 7'h7f};
            else
                model_data <= #180 {model_data[14:0], 1'b0};
        assign serial_data = model_data[15];
`endif
`ifdef LCD_SIN_LUT_HARDWARE
`undef LCD_SIN_LUT_HARDWARE
`endif
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                done <= 0;
                value <= 0;
                state <= IDLE;
                phase <= 0;
                bit_count <= 0;
                addr_shift <= 0;
                arclk <= 0;
                drclk <= 0;
                drshft <= 1;
            end else begin
                done <= 0;
                // Free-running divider: transaction start never resets phase.
                // The gated serial pulses therefore have a fixed clock phase.
                phase <= phase + 1'b1;
                case (state)
                    IDLE: if (request) begin
                        addr_shift <= {2'b0, address};
                        bit_count <= 0;
                        state <= ALIGN;
                    end
                    ALIGN: if (phase == 31) state <= ADDR;
                    ADDR: begin
                        if (phase == 0) arclk <= 1;
                        if (phase == 16) begin
                            arclk <= 0;
                            addr_shift <= {addr_shift[7:0],1'b0};
                        end
                        if (phase == 31) begin
                            if (bit_count == 8) begin
                                state <= WAIT_ACCESS;
                                bit_count <= 0;
                            end else bit_count <= bit_count + 1'b1;
                        end
                    end
                    WAIT_ACCESS: begin
                        if (phase == 16) drshft <= 0;
                        if (phase == 31) state <= LOAD;
                    end
                    LOAD: begin
                        if (phase == 0) drclk <= 1;
                        if (phase == 16) begin
                            drclk <= 0;
                            drshft <= 1;
                        end
                        if (phase == 31) begin
                            value <= {value[7:0], serial_data};
                            state <= SHIFT;
                        end
                    end
                    SHIFT: begin
                        if (phase == 0) drclk <= 1;
                        if (phase == 16) drclk <= 0;
                        if (phase == 31) begin
                            value <= {value[7:0], serial_data};
                            if (bit_count == 7) begin
                                done <= 1;
                                state <= IDLE;
                            end else bit_count <= bit_count + 1'b1;
                        end
                    end
                    default: state <= IDLE;
                endcase
            end
        end
    end endgenerate
endmodule
