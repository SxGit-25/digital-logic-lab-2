`timescale 1ns/1ps
module tb_alarm_ctrl;
    reg clk=0, rst=1, valid=1;
    reg [1:0] state=3;
    reg [2:0] level=0;
    wire [15:0] leds;
    wire buzzer;
    integer i, period_ms, selected;
    always #5 clk=~clk;
    alarm_ctrl #(.CARRIER_HALF_US(1)) dut
      (clk,rst,1'b1,1'b1,1'b1,state,valid,level,leds,buzzer);
    task reset_alarm;
      begin
        @(negedge clk); rst=1;
        @(negedge clk); rst=0;
      end
    endtask
    initial begin
      for (selected=2; selected<=5; selected=selected+1) begin
        level=selected;
        period_ms=1000 >> (selected-2);
        reset_alarm;
        for(i=0;i<2*period_ms;i=i+1) begin
          @(posedge clk); #1;
          if(dut.sound_gate !== ((i%period_ms)<50))
            $fatal(1,"alarm envelope mismatch level=%0d tick=%0d",selected,i);
          if(buzzer !== (dut.carrier && dut.sound_gate)) $fatal(1,"carrier gating");
        end
      end
      level=2; reset_alarm;
      repeat(800) @(posedge clk);
      @(negedge clk); level=5;
      @(posedge clk); #1;
      if(dut.rhythm_ms !== 0) $fatal(1,"shorter period must recover at next tick");
      @(posedge clk); #1;
      if(!dut.sound_gate) $fatal(1,"alarm did not resume after level change");
      @(negedge clk); valid=0;
      @(posedge clk); #1;
      if(buzzer || leds) $fatal(1,"invalid distance must silence alarm");
      @(negedge clk); valid=1; state=0;
      @(posedge clk); #1;
      if(buzzer || leds) $fatal(1,"off must silence alarm");
      $display("PASS tb_alarm_ctrl: all four rhythms, period shortening, invalid/off");
      $finish;
    end
    initial begin #100000; $fatal(1,"timeout"); end
endmodule
