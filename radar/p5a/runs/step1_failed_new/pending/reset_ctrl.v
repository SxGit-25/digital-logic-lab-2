`timescale 1ns/1ps

// MAX II registers support a defined power-up value.  Quartus must preserve
// this initializer; check the Power-Up Level column after compilation.
module reset_ctrl #(
    parameter integer RESET_CYCLES = 16
) (
    input  wire clk,
    output wire rst
);
    function integer width;
        input integer count;
        begin width=1; while ((2**width)<count) width=width+1; end
    endfunction
    reg [width(RESET_CYCLES)-1:0] elapsed = 0;
    reg active = 1'b1;
    always @(posedge clk) begin
        if(active) begin
            if(elapsed==RESET_CYCLES-1) active<=0;
            else elapsed<=elapsed+1'b1;
        end
    end
    assign rst = active;
endmodule
