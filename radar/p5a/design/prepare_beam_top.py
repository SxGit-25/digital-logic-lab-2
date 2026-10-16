from pathlib import Path
root=Path(__file__).resolve().parents[3]
out=Path(__file__).parent/'step4_source'
s=(root/'radar/rtl/radar_unified_top.v').read_text()
s=s.replace(' parameter P5_INVERT=0,',' parameter P5_INVERT=0,\n parameter P5_BEAM=0,')
s=s.replace(' wire lcd_reset=rst || !system_on || system_state==0;', ''' // Keep a mode/off request until the single LCD sequencer has removed XOR.
 reg lcd_restart_pending;
 wire draw_quiescent;
 wire lcd_stop=!system_on || system_state==0 || lcd_restart_pending;
 wire lcd_reset=P5_BEAM ? rst || (lcd_stop && draw_quiescent) :
                         rst || !system_on || system_state==0;
 always @(posedge clk) begin
   if(rst) lcd_restart_pending<=1;
   else if(!system_on || system_state==0) lcd_restart_pending<=1;
   else if(lcd_reset) lcd_restart_pending<=0;
 end''')
s=s.replace('.P5_INVERT(P5_INVERT),','.P5_INVERT(P5_INVERT),.P5_BEAM(P5_BEAM),')
s=s.replace('  .continuous_mode(mode_continuous),','  .continuous_mode(mode_continuous),\n  .stop_request(lcd_stop),.quiescent(draw_quiescent),')
(out/'radar_unified_top.v').write_text(s)
s=(root/'radar/unified_scan/radar_unified_variants.v').read_text()
s=s.replace('P5_INVERT=0)(', 'P5_INVERT=0, P5_BEAM=0)(')
s=s.replace('.P5_INVERT(P5_INVERT)) system(','.P5_INVERT(P5_INVERT),.P5_BEAM(P5_BEAM)) system(')
(out/'radar_unified_variants.v').write_text(s)
