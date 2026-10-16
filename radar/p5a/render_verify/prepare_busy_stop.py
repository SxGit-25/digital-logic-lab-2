from pathlib import Path
import argparse
from reference import Reference,load_background

p=argparse.ArgumentParser();p.add_argument('out',type=Path);p.add_argument('--mode',choices=['basic','continuous'],required=True);p.add_argument('--background',type=Path,required=True);a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
model=Reference(load_background(a.background),continuous=a.mode=='continuous',beam=True)
warm=[];stopped=[];inputs=[]
for phase in range(5):
    angle=20+phase*29
    case=dict(angle=angle,up=True,radius=24,valid=True)
    model.request(**case);warm.extend(model.ram)
    new=dict(angle=angle+5,up=True,radius=31,valid=True)
    if phase>=2:model.request(**new)
    model.remove_beam();stopped.extend(model.ram)
    def pack(case):
        n=case['angle'];bcd=(n//100)*256+((n//10)%10)*16+n%10
        return (bcd<<8)|(int(case['up'])<<7)|(int(case['valid'])<<6)|case['radius']
    inputs.extend([pack(case),pack(new)])
for name,values,width in [('busy_inputs.mem',inputs,5),('warm_expected.mem',warm,2),('stop_expected.mem',stopped,2)]:
    (a.out/name).write_text(''.join(f'{v:0{width}x}\n' for v in values))
(a.out/'busy_mode.vh').write_text(f'`define BUSY_CONTINUOUS {int(a.mode=="continuous")}\n')
