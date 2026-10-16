`timescale 1ns/1ps
module tb_alarm_global;
 reg enable=1,blink=0,carrier=1,window=0,valid=1;
 reg [2:0] phase=0,level=0;reg [1:0] state=3;
 wire [15:0] leds;wire buzzer;
 alarm_global a(enable,blink,carrier,window,phase,state,valid,level,leds,buzzer);
 integer l,m,expected,counts,pulses,prev,tests=0;
 reg [15:0] mask;
 initial begin
  for(l=0;l<8;l=l+1) begin
   level=l;counts=0;pulses=0;prev=0;
   for(m=0;m<1000;m=m+1) begin
    phase=m/125;window=(m%125)<50;blink=(m%500)<250;
    expected=l==2 ? (m%1000)<50 : l==3 ? (m%500)<50 : l==4 ? (m%250)<50 : l==5 ? (m%125)<50 : 0;
    case(l)
     1:mask=16'hf000;2:mask=blink ? 16'h0f00:0;
     3:mask=blink ? 16'h00f0:0;4:mask=blink ? 16'h000f:0;
     5:mask=blink ? 16'hffff:0;default:mask=0;
    endcase
    #1;
    if(buzzer!==expected[0] || leds!==mask)$fatal(1,"alarm rhythm/mask l=%0d ms=%0d",l,m);
    if(buzzer) counts=counts+1;
    if(buzzer&&!prev)pulses=pulses+1;
    prev=buzzer;tests=tests+1;
   end
   if(l>=2&&l<=5 && (pulses!=(1<<(l-2)) || counts!=50*(1<<(l-2))))$fatal(1,"rhythm pulse coverage");
  end
  level=5;phase=0;window=1;blink=1;
  valid=0;#1;if(leds||buzzer)$fatal(1,"invalid alarm");
  valid=1;state=1;#1;if(leds!=16'hffff || buzzer)$fatal(1,"selftest");
  blink=0;#1;if(leds||buzzer)$fatal(1,"selftest blink");
  state=2;#1;if(leds||buzzer)$fatal(1,"standby");
  state=3;enable=0;#1;if(leds||buzzer)$fatal(1,"immediate disable");
  $display("PASS global alarm %0d phase cases, four rates, 50ms windows, masks, invalid/off/self",tests);
  $finish;
 end
endmodule
