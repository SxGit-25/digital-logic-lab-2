# Postfit 实测报告

|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|
|---|---|---|---|---|---|---|
|1|3.190|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[5]|radar_unified_top:system|radar_lcd_micro:draw|position_count[3]|7|11.573|70%|
|2|3.192|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[5]|radar_unified_top:system|radar_lcd_micro:draw|position_count[6]|7|11.571|70%|
|3|3.192|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[5]|radar_unified_top:system|radar_lcd_micro:draw|position_count[1]|7|11.571|70%|
|4|3.194|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[5]|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|7|11.569|70%|
|5|3.300|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[4]|radar_unified_top:system|radar_lcd_micro:draw|position_count[3]|7|11.692|71%|
|6|3.302|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[4]|radar_unified_top:system|radar_lcd_micro:draw|position_count[6]|7|11.690|71%|
|7|3.302|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[4]|radar_unified_top:system|radar_lcd_micro:draw|position_count[1]|7|11.690|71%|
|8|3.304|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[4]|radar_unified_top:system|radar_lcd_micro:draw|position_count[5]|7|11.688|71%|
|9|3.457|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[5]|radar_unified_top:system|radar_lcd_micro:draw|position_count[3]|7|11.519|71%|
|10|3.458|radar_unified_top:system|radar_lcd_micro:draw|latest_angle[5]|radar_unified_top:system|radar_lcd_micro:draw|position_count[1]|7|11.518|71%|

CDC 三项断言：PASS。

|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|
|---|---|---|---|---|---|
|Illegal Clocks|0|0|0|0|0|
|Unconstrained Clocks|0|0|0|0|0|
|Unconstrained Input Ports|0|0|0|0|0|
|Unconstrained Input Port Paths|0|0|0|0|0|
|Unconstrained Output Ports|58|58|58|0|0|
|Unconstrained Output Port Paths|456|456|456|0|0|
