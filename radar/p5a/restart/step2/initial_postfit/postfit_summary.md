# Postfit 实测报告

|排名|Setup ns|起点|终点|逻辑级|数据布线 ns|布线占比|
|---|---|---|---|---|---|---|
|1|0.815|radar_unified_top:system\|radar_lcd_micro:draw\|p5_ufm_reader:g_background.background_reader\|addr_shift[8]|radar_unified_top:system\|radar_lcd_micro:draw\|p5_ufm_reader:g_background.background_reader\|altufm_none:flash\|altufm_none_1km:auto_generated\|maxii_ufm_block1~OBSERVABLEADDRESSREGOUT|0|1.147|75%|
|2|0.820|radar_unified_top:system\|radar_lcd_micro:draw\|p5_ufm_reader:g_background.background_reader\|arshft|radar_unified_top:system\|radar_lcd_micro:draw\|p5_ufm_reader:g_background.background_reader\|altufm_none:flash\|altufm_none_1km:auto_generated\|maxii_ufm_block1~OBSERVABLEADDRESSREGOUT|0|1.142|75%|
|3|3.414|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[2]|6|11.108|68%|
|4|3.658|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[5]|5|11.708|73%|
|5|3.850|radar_unified_top:system\|radar_lcd_micro:draw\|latest_angle[1]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[2]|7|11.241|71%|
|6|3.882|radar_unified_top:system\|lcd_bus_phase:bus\|lcd_rd_n|lcd_rd_n|0|4.601|63%|
|7|3.923|radar_unified_top:system\|radar_unified_scan:scan\|system_state[1]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[2]|6|11.139|70%|
|8|4.000|radar_unified_top:system\|radar_lcd_micro:draw\|latest_angle[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[2]|7|11.265|71%|
|9|4.018|radar_unified_top:system\|radar_lcd_micro:draw\|initialized|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[2]|6|11.218|71%|
|10|4.045|radar_unified_top:system\|radar_unified_scan:scan\|system_state[0]|radar_unified_top:system\|radar_lcd_micro:draw\|position_count[3]|5|10.366|66%|

CDC 三项断言：PASS。

|未约束项目|Setup|Hold|基线|Setup 增减|Hold 增减|
|---|---|---|---|---|---|
|Illegal Clocks|0|0|0|0|0|
|Unconstrained Clocks|0|0|0|0|0|
|Unconstrained Input Ports|0|0|0|0|0|
|Unconstrained Input Port Paths|0|0|0|0|0|
|Unconstrained Output Ports|58|58|58|0|0|
|Unconstrained Output Port Paths|456|456|456|0|0|
