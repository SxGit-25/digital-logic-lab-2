`timescale 1ns/1ps
// Beam updates are independent of the slower ultrasonic results. Each integer
// angle receives A/B; an echo receives B only at its latched measurement angle.
// A new turn invalidates old-epoch targets so an old echo cannot repaint the
// end zone after the direction-change clearing batch.
module radar_lcd_bridge(
    input wire clk,rst,enable,
    input wire [7:0] beam_angle,
    input wire beam_direction_up,
    input wire measure_start,measure_done,
    input wire [7:0] sample_angle,
    input wire sample_direction_up,
    input wire [5:0] radius,
    input wire radius_valid,
    input wire lcd_ready,lcd_done,
    output wire request,
    output reg [7:0] angle,
    output reg direction_up,
    output reg [5:0] draw_radius,
    output reg draw_valid,
    output reg plot_only
);
    reg tracking,seen_direction,epoch,sample_epoch;
    reg [7:0] seen_angle,target_angle;
    reg beam_pending,target_pending,target_direction;
    reg [5:0] target_radius;
    reg target_valid;
    reg active;
    wire turn_event=tracking && beam_direction_up!=seen_direction;
    wire current_epoch=epoch ^ turn_event;
    wire beam_event=!tracking || beam_angle!=seen_angle || turn_event;
    // Register the request arguments first, then keep them stable until done.
    reg launch;
    assign request=launch && enable;
    always @(posedge clk) begin
        if(rst || !enable) begin
            tracking<=0;seen_direction<=1;epoch<=0;sample_epoch<=0;seen_angle<=0;
            beam_pending<=0;
            target_pending<=0;target_angle<=0;target_direction<=1;
            target_radius<=0;target_valid<=0;active<=0;launch<=0;
            angle<=0;direction_up<=1;draw_radius<=0;draw_valid<=0;plot_only<=0;
        end else begin
            launch<=0;
            if(lcd_done) active<=0;
            if(measure_start) sample_epoch<=current_epoch;
            if(!active && !launch && lcd_ready) begin
                if(beam_pending) begin
                    angle<=seen_angle;direction_up<=seen_direction;
                    draw_radius<=0;draw_valid<=0;plot_only<=0;
                    beam_pending<=0;active<=1;launch<=1;
                end else if(target_pending && !turn_event && !beam_event) begin
                    angle<=target_angle;direction_up<=target_direction;
                    draw_radius<=target_radius;draw_valid<=target_valid;plot_only<=1;
                    target_pending<=0;active<=1;launch<=1;
                end
            end
            if(beam_event) begin
                tracking<=1;seen_angle<=beam_angle;seen_direction<=beam_direction_up;
                beam_pending<=1;
            end
            if(turn_event) begin epoch<=~epoch;target_pending<=0;end
            if(measure_done && sample_epoch==current_epoch) begin
                target_angle<=sample_angle;target_direction<=sample_direction_up;
                target_radius<=radius;target_valid<=radius_valid;target_pending<=1;
            end
        end
    end
endmodule
