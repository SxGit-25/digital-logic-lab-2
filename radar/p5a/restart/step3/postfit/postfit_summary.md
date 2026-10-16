# Postfit 实测报告

|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|
|---|---|---|---|---|---|---|
|1|3.918|radar_unified_top:system\|lcd_bus_phase:bus\|lcd_rd_n|lcd_rd_n|0|4.565|62%|
|2|3.979|radar_unified_top:system\|lcd_bus_phase:bus\|lcd_wr_n|lcd_wr_n|0|4.504|62%|
|3|4.184|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[2]|6|11.364|73%|
|4|4.187|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[4]|6|11.361|73%|
|5|4.191|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|6|11.357|73%|
|6|4.256|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[3]|7|10.781|69%|
|7|4.260|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[5]|7|10.777|69%|
|8|4.262|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[1]|7|10.775|69%|
|9|4.267|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[6]|7|10.770|69%|
|10|4.319|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|6|10.820|70%|

CDC 三项断言：PASS。

|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|
|---|---|---|---|---|---|
|Illegal Clocks|0|0|0|0|0|
|Unconstrained Clocks|0|0|0|0|0|
|Unconstrained Input Ports|0|0|0|0|0|
|Unconstrained Input Port Paths|0|0|0|0|0|
|Unconstrained Output Ports|58|58|58|0|0|
|Unconstrained Output Port Paths|456|456|456|0|0|
