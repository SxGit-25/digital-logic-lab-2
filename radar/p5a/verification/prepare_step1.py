"""Derive step1 fixtures from the frozen independent Minsky integer reference.

Only the specified A-angle policy and busy-request expectations change.
Existing production test files are not rewritten.
"""
from pathlib import Path
import argparse, types
ROOT = Path(__file__).resolve().parents[3]
p = argparse.ArgumentParser()
p.add_argument('stage', type=Path)
p.add_argument('--mode', choices=['basic', 'continuous'], required=True)
a = p.parse_args()
continuous = a.mode == 'continuous'
source = ROOT / 'radar/sim/unified_scan/minsky_draw_fixtures.py'
text = source.read_text(encoding='utf-8')
old = 'else [a+10] if up and a<=170 else [a-10] if not up and a>=10 else []'
assert old in text
if not continuous:
    text = text.replace(old, 'else [a]')
module = types.ModuleType('step1_reference')
module.__file__ = str(source)
exec(compile(text, str(source), 'exec'), module.__dict__)
module.prepare(a.stage, 'f15', False)
tb = (ROOT / 'radar/sim/unified_scan/tb_budget_draw.v').read_text(encoding='utf-8')
tb = tb.replace('.ENABLE_READBACK(1),.FRACTION_BITS', '.ENABLE_READBACK(1),.P5_FIXES(1),.FRACTION_BITS')
tb = tb.replace('.clk(clk),.rst(rst),.tick_ms', f'.continuous_mode(1\'b{int(continuous)}),.clk(clk),.rst(rst),.tick_ms')
if not continuous:
    tb = tb.replace('else ray_index=accepted_direction?wanted_angle+10:wanted_angle-10;', 'else ray_index=wanted_angle;')
    tb = tb.replace('(direction_up && wanted_angle<=170)||(!direction_up && wanted_angle>=10)?1:0;', '1;')
start = tb.index('   if(scenario==`DRAW_SCENARIOS-1) begin')
end = tb.index('   wait(done);', start)
tb = tb[:start] + '   // No request strobe: external changes must not alter snapshot.\n' + tb[end:]
tb = tb.replace('  $display("PASS tb_minsky_draw");', f'  $display("PASS step1_{a.mode} merged=0");')
(a.stage / 'tb_step1_draw.v').write_text(tb, encoding='ascii')
