# Postfit 实测报告

|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|
|---|---|---|---|---|---|---|
|1|3.456|radar_unified_top:system\|radar_lcd_micro:draw\|return_ten|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|7|11.794|72%|
|2|3.484|radar_unified_top:system\|radar_lcd_micro:draw\|beam_valid|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|6|11.655|72%|
|3|3.504|radar_unified_top:system\|switch_pair_sampled:u_switch_pair\|system_on|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|6|11.635|71%|
|4|3.566|radar_unified_top:system\|radar_lcd_micro:draw\|latest_angle[5]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|7|11.236|69%|
|5|3.614|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[3]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.813|73%|
|6|3.653|radar_unified_top:system\|radar_lcd_micro:draw\|state.VECTOR_RESET|radar_unified_top:system\|radar_lcd_micro:draw\|minsky_serial_registers:datapath\|y_acc[21]|6|12.292|76%|
|7|3.657|radar_unified_top:system\|radar_lcd_micro:draw\|state.VECTOR_RESET|radar_unified_top:system\|radar_lcd_micro:draw\|minsky_serial_registers:datapath\|y_acc[21]|6|12.288|76%|
|8|3.715|radar_unified_top:system\|radar_lcd_micro:draw\|latest_angle[6]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|7|11.261|70%|
|9|3.733|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[3]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|8|11.354|71%|
|10|3.737|radar_unified_top:system\|switch_pair_sampled:u_switch_pair\|system_on|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|6|11.805|74%|

CDC 三项断言：PASS。

|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|
|---|---|---|---|---|---|
|Illegal Clocks|0|0|0|0|0|
|Unconstrained Clocks|0|0|0|0|0|
|Unconstrained Input Ports|0|0|0|0|0|
|Unconstrained Input Port Paths|0|0|0|0|0|
|Unconstrained Output Ports|58|58|58|0|0|
|Unconstrained Output Port Paths|456|456|456|0|0|
