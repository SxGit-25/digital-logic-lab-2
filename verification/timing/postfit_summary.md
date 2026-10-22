# Postfit 实测报告

|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|
|---|---|---|---|---|---|---|
|1|2.994|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[2]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.097|66%|
|2|3.152|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[2]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.168|67%|
|3|3.165|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[1]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.100|67%|
|4|3.323|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[1]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.171|68%|
|5|3.337|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[3]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.157|68%|
|6|3.401|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[2]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[3]|8|10.686|65%|
|7|3.401|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[2]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[1]|8|10.686|65%|
|8|3.475|radar_unified_top:system\|radar_lcd_micro:draw\|initialized|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|8|10.495|64%|
|9|3.479|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[2]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.152|68%|
|10|3.495|radar_unified_top:system\|radar_lcd_micro:draw\|bit_index[3]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[0]|9|11.228|69%|

CDC 三项断言：PASS。

|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|
|---|---|---|---|---|---|
|Illegal Clocks|0|0|0|0|0|
|Unconstrained Clocks|0|0|0|0|0|
|Unconstrained Input Ports|0|0|0|0|0|
|Unconstrained Input Port Paths|0|0|0|0|0|
|Unconstrained Output Ports|58|58|58|0|0|
|Unconstrained Output Port Paths|456|456|456|0|0|
