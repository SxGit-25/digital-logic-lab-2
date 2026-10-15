"""Independent fixture from the Minsky agent's integer vector reference."""
from pathlib import Path
import argparse, importlib.util, json, sys
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
def bcd(a): return (a//100)*256+((a//10)%10)*16+a%10
def prepare(stage,candidate,smoke=False):
    stage=Path(stage);stage.mkdir(parents=True,exist_ok=True)
    f,k,bits,add,initial,base=(15,7,6,15,63,2) if candidate=='f15' else (17,8,5,15,16,4)
    source=ROOT/'radar/unified_scan/results/minsky/minsky_schedule_search.py'
    spec=importlib.util.spec_from_file_location('minsky_agent_reference',source)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    result,vectors=module.evaluate(k,f,1<<bits,add,initial)
    assert result is not None
    q=1<<f
    scenarios=[]
    for a in range(181):scenarios.append((a,1,(a*7)%49,a%11==0))
    scenarios.append((180,0,48,False))
    for a in range(179,0,-1):scenarios.append((a,0,(a*7)%49,a%11==0))
    scenarios.append((0,1,0,False))
    if smoke:
        scenarios=[(0,1,0,False),(1,1,2,True),(10,1,12,True),(45,1,24,True),
                   (90,1,36,True),(170,1,48,True),(180,1,48,False),
                   (180,0,48,False),(179,0,18,True),(90,0,28,True),
                   (10,0,8,True),(1,0,48,False),(0,1,0,False)]
    full_index=len(scenarios)-1
    scenarios += [(90,1,8,True),(90,1,18,True),(90,1,28,True),(91,1,13,True),
                  (180,0,36,True),(179,0,24,True),(0,1,48,False),
                  (1,1,0,True),(2,1,2,True),(3,1,48,True),
                  (4,1,48,False),(5,1,49,True),(180,0,28,True)]
    pixels=[];packed=[];meta=[]
    for index,(a,up,r,valid) in enumerate(scenarios):
        erase_angles=list(range(170,181)) if a==180 and not up else list(range(11)) if a==0 and up else [a+10] if up and a<=170 else [a-10] if not up and a>=10 else []
        before=len(pixels)
        for erase,ray in [(True,x) for x in erase_angles]+[(False,a)]:
            c,s=vectors[ray]
            for step in range(6,49):
                ring=step in (16,32,48)
                selected=not ring if erase else ring or (valid and r<=48 and step==max(6,r))
                if not selected:continue
                x=64+(step*c+q//2)//q;y=63-(step*s+q//2)//q
                assert 0<=x<128 and 0<=y<64,(a,ray,step,x,y)
                pixels.append((int(erase)<<18)|((y//8)<<15)|(x<<8)|(1<<(y%8)))
        count=len(pixels)-before
        packed.append((bcd(a)<<20)|(up<<19)|(r<<13)|(int(valid)<<12)|count)
        meta.append(dict(index=index,angle=a,direction_up=up,radius=r,valid=bool(valid),erase_rays=len(erase_angles),rmw_pixels=count))
    (stage/'scenarios.hex').write_text(''.join(f'{v:08x}\n' for v in packed))
    (stage/'pixels.hex').write_text(''.join(f'{v:05x}\n' for v in pixels))
    mask=(1<<(f+2))-1
    for coordinate,slot in (('c',0),('s',1)):
        (stage/f'vectors_{coordinate}.hex').write_text(''.join(f'{v[slot]&mask:x}\n' for v in vectors))
    (stage/'draw_counts.vh').write_text(f'`define DRAW_SCENARIOS {len(scenarios)}\n`define DRAW_PIXELS {len(pixels)}\n`define FULL_INDEX {full_index}\n')
    (stage/'scenario_reference.json').write_text(json.dumps(dict(candidate=candidate,smoke=smoke,f=f,k=k,phase_bits=bits,phase_add=add,phase_initial=initial,micro_base=base,reference_source=str(source),vector_evaluation=result,scenarios=meta),indent=2))
    print('PREPARED',candidate,len(scenarios),'requests',len(pixels),'independent RMW pixels')
def images(stage):
    from PIL import Image
    for path in Path(stage).glob('*.pbm'):
        image=Image.open(path).convert('RGB')
        image.resize((768,384),Image.Resampling.NEAREST).save(path.with_suffix('.png'))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['prepare','images']);p.add_argument('stage');p.add_argument('--candidate',default='f17');p.add_argument('--smoke',action='store_true');a=p.parse_args()
    prepare(a.stage,a.candidate,a.smoke) if a.action=='prepare' else images(a.stage)
