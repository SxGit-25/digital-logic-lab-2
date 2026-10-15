from pathlib import Path
import math
root=Path(__file__).resolve().parents[2]; out=root/'radar/lcd_p1'
mem=[0]*1024
for r in (16,32,48):
 for a in range(181):
  x=64+int(math.floor(r*math.cos(math.radians(a))+.5))
  y=63-int(math.floor(r*math.sin(math.radians(a))+.5))
  mem[(y//8)*128+x]|=1<<(y%8)
s='''`timescale 1ns/1ps
// P1 ONLY: precomputed reference image, not the P2 ray-engine implementation.
// Reproduce with radar/lcd_p1/generate_pattern.py.
module lcd_p1_pattern(input wire [9:0] address, output reg [7:0] value);
 always @* begin
  case(address)
'''
for i,v in enumerate(mem):
 if v:s+=f"   10'd{i}: value=8'h{v:02x};\n"
s+="   default:value=0;\n  endcase\n end\nendmodule\n"
(root/'radar/rtl/lcd_p1_pattern.v').write_text(s)
(out/'expected.hex').write_text(''.join(f'{v:02x}\n' for v in mem))
