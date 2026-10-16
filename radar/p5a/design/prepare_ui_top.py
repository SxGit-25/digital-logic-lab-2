from pathlib import Path
import argparse,shutil
p=argparse.ArgumentParser();p.add_argument('step',type=int);p.add_argument('--digits',action='store_true');p.add_argument('--mode',action='store_true');p.add_argument('--level',action='store_true');a=p.parse_args()
root=Path(__file__).resolve().parents[3];out=Path(__file__).parent/f'step{a.step}_source';out.mkdir(exist_ok=True)
for f in (root/'radar/rtl').glob('*.v'):shutil.copy2(f,out/f.name)
shutil.copy2(Path(__file__).with_name('radar_lcd_micro_ui.v'),out/'radar_lcd_micro.v')
s=(root/'radar/rtl/radar_unified_top.v').read_text()
s=s.replace(' parameter P5_INVERT=0,',' parameter P5_INVERT=0,\n parameter P5_DIGITS=0,P5_MODE=0,P5_LEVEL=0,')
s=s.replace('.P5_INVERT(P5_INVERT),','.P5_INVERT(P5_INVERT),.P5_DIGITS(P5_DIGITS),.P5_MODE(P5_MODE),.P5_LEVEL(P5_LEVEL),')
s=s.replace('  .continuous_mode(mode_continuous),','  .continuous_mode(mode_continuous),\n  .distance_bcd(distance_bcd),.level(current_level),')
(out/'radar_unified_top.v').write_text(s)
s=(root/'radar/unified_scan/radar_unified_variants.v').read_text()
s=s.replace('P5_INVERT=0)(', 'P5_INVERT=0, P5_DIGITS=0, P5_MODE=0, P5_LEVEL=0)(')
s=s.replace('.P5_INVERT(P5_INVERT)) system(','.P5_INVERT(P5_INVERT),.P5_DIGITS(P5_DIGITS),.P5_MODE(P5_MODE),.P5_LEVEL(P5_LEVEL)) system(')
(out/'radar_unified_variants.v').write_text(s)
variant='digits_level' if a.digits and a.level else 'digits' if a.digits else 'level' if a.level else 'base'
for suffix in ('mif','mem','hex'):shutil.copy2(root/f'radar/p5a/background/{variant}/background.{suffix}',out/f'background.{suffix}')
