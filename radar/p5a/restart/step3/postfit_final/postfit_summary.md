# Postfit 实测报告

|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|
|---|---|---|---|---|---|---|
|1|3.361|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|dropped[6]|10|10.501|64%|
|2|3.410|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|dropped[6]|10|10.501|64%|
|3|3.521|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|dropped[4]|9|10.975|67%|
|4|3.572|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|dropped[4]|9|10.975|68%|
|5|3.652|radar_unified_top:system\|radar_lcd_micro:draw\|second_op|radar_unified_top:system\|radar_lcd_micro:draw\|minsky_serial_registers:datapath\|y_acc[21]|6|12.512|78%|
|6|3.673|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[4]|6|11.170|69%|
|7|3.754|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[1]|7|12.171|76%|
|8|3.756|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[3]|7|12.169|76%|
|9|3.763|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[5]|7|12.162|76%|
|10|3.768|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[6]|7|12.157|76%|

CDC 三项断言：PASS。

|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|
|---|---|---|---|---|---|
|Illegal Clocks|0|0|0|0|0|
|Unconstrained Clocks|0|0|0|0|0|
|Unconstrained Input Ports|0|0|0|0|0|
|Unconstrained Input Port Paths|0|0|0|0|0|
|Unconstrained Output Ports|58|58|58|0|0|
|Unconstrained Output Port Paths|456|456|456|0|0|
