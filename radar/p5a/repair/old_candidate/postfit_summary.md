# Postfit 实测报告

|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|
|---|---|---|---|---|---|---|
|1|0.970|radar_unified_top:system|radar_unified_scan:scan|sample_event|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|6|14.425|77%|
|2|1.154|radar_unified_top:system|radar_unified_scan:scan|sample_event|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|6|14.781|79%|
|3|1.579|radar_unified_top:system|radar_unified_scan:scan|sample_event|radar_unified_top:system|radar_lcd_micro:draw|position_count[3]|6|13.292|73%|
|4|1.694|radar_unified_top:system|switch_pair_sampled:u_switch_pair|sw_sync[0]|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|7|13.730|76%|
|5|1.793|radar_unified_top:system|radar_unified_scan:scan|sample_angle_bcd[5]|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|6|12.888|72%|
|6|1.813|radar_unified_top:system|switch_pair_sampled:u_switch_pair|sw_sync[0]|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|8|13.585|76%|
|7|1.847|radar_unified_top:system|radar_unified_scan:scan|sample_event|radar_unified_top:system|radar_lcd_micro:draw|position_count[1]|7|12.567|70%|
|8|1.869|radar_unified_top:system|switch_pair_sampled:u_switch_pair|sw_sync[0]|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|7|13.729|77%|
|9|1.878|radar_unified_top:system|switch_pair_sampled:u_switch_pair|sw_sync[0]|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|7|14.086|79%|
|10|1.945|radar_unified_top:system|radar_unified_scan:scan|sample_event|radar_unified_top:system|radar_lcd_micro:draw|position_count[6]|6|13.466|75%|

CDC 三项断言：PASS。

|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|
|---|---|---|---|---|---|
|Illegal Clocks|0|0|0|0|0|
|Unconstrained Clocks|0|0|0|0|0|
|Unconstrained Input Ports|0|0|0|0|0|
|Unconstrained Input Port Paths|0|0|0|0|0|
|Unconstrained Output Ports|58|58|58|0|0|
|Unconstrained Output Port Paths|456|456|456|0|0|
