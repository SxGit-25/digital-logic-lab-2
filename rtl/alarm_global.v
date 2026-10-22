`timescale 1ns/1ps
// Rhythm phase and carrier come from the single system timebase.
module alarm_global #(
 parameter [15:0] BLUE_MASK=16'hf000,GREEN_MASK=16'h0f00,
 parameter [15:0] YELLOW_MASK=16'h00f0,RED_MASK=16'h000f
)(
 input wire enable,blink_2hz,carrier_2khz,window_50ms,
 input wire [2:0] rhythm_phase,
 input wire [1:0] system_state,
 input wire current_valid,
 input wire [2:0] current_level,
 output reg [15:0] leds,
 output wire buzzer
);
 reg beat;
 always @* begin
  case(current_level)
   2:beat=rhythm_phase==0;
   3:beat=rhythm_phase[1:0]==0;
   4:beat=rhythm_phase[0]==0;
   5:beat=1;
   default:beat=0;
  endcase
  leds=0;
  if(enable) begin
   if(system_state==1) leds=blink_2hz ? 16'hffff : 16'h0000;
   else if(system_state==3 && current_valid) begin
    case(current_level)
     1:leds=BLUE_MASK;
     2:leds=blink_2hz ? GREEN_MASK : 16'h0000;
     3:leds=blink_2hz ? YELLOW_MASK : 16'h0000;
     4:leds=blink_2hz ? RED_MASK : 16'h0000;
     5:leds=blink_2hz ? 16'hffff : 16'h0000;
     default:leds=0;
    endcase
   end
  end
 end
 assign buzzer=enable && system_state==3 && current_valid && beat && window_50ms && carrier_2khz;
endmodule
