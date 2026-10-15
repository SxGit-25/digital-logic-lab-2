"""Search simple power-of-two fractional microstep schedules; no RTL changes."""
from pathlib import Path
import csv,importlib.util,json,math,sys
sys.dont_write_bytecode=True
import numpy as np
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('minsky_study',HERE/'minsky_feasibility.py')
study=importlib.util.module_from_spec(spec);spec.loader.exec_module(study)
angles=np.arange(181)*math.pi/180;radii=np.arange(49)
ideal_c=np.cos(angles);ideal_s=np.sin(angles)
ideal_x=ideal_c[:,None]*radii;ideal_y=ideal_s[:,None]*radii


def evaluate(k,f,d,p,phase0):
    q=1<<f;c=q;s=0;phase=phase0;states=[(c,s)];base=int((math.pi/180)/(2*math.asin(2**-k/2)))
    for a in range(1,181):
        n=base+(phase+p)//d;phase=(phase+p)%d
        for _ in range(n):c-=s>>k;s+=c>>k
        states.append((c,s))
    v=np.array(states,dtype=np.int64)
    unrounded=np.max(48*np.hypot(v[:,0]/q-ideal_c,v[:,1]/q-ideal_s))
    if unrounded>1+math.sqrt(.5):return None,states
    x=(v[:,0,None]*radii+q//2)//q;y=(v[:,1,None]*radii+q//2)//q
    errors=np.hypot(x-ideal_x,y-ideal_y)
    worst=float(errors.max())
    if worst>1:return None,states
    actual=np.degrees(np.arctan2(v[:,1],v[:,0]));diff=(actual-np.arange(181)+180)%360-180
    mag=np.hypot(v[:,0],v[:,1])/q
    return dict(k=k,fraction_bits=f,signed_register_bits=f+2,base_microsteps=base,
        numerator=p,denominator=d,initial_phase=phase0,maximum_pixel_euclidean_error_px=worst,
        maximum_unrounded_vector_error_px=float(unrounded),angle_after_45_steps=float(actual[45]),
        maximum_direction_angle_error_degrees=float(np.abs(diff).max()),
        maximum_magnitude_error_px_at_radius_48=float((np.abs(mag-1)*48).max())),states


def main():
    passing=[];tested=0
    for f in range(8,17):
        for k in (6,7,8,9):
            for d in (1,2,4,8,16,32,64,128,256):
                for p in range(d+1):
                    if d>1 and p%2==0:continue # same rational already covered
                    for phase in sorted({0,d//4,d//2,3*d//4,d-1}):
                        result,_=evaluate(k,f,d,p,phase);tested+=1
                        if result is not None:passing.append(result)
        print('F',f,'pixel-passing so far',len(passing),flush=True)
    zero=[];checked=[]
    for f in range(8,17):
        options=sorted((v for v in passing if v['fraction_bits']==f),key=lambda v:(v['denominator'],v['k'],v['maximum_pixel_euclidean_error_px']))
        for row in options:
            _,states=evaluate(row['k'],f,row['denominator'],row['numerator'],row['initial_phase'])
            row['erase_check']=study.erase_check(states,f);checked.append(row)
            if row['erase_check']['at_minimum_6']['behind_hits']==0:
                c,s=states[-1];phase=(row['initial_phase']+180*row['numerator'])%row['denominator']
                for angle in range(180,0,-1):
                    previous_phase=(phase-row['numerator'])%row['denominator']
                    n=row['base_microsteps']+(previous_phase+row['numerator'])//row['denominator']
                    for _ in range(n):s-=c>>row['k'];c+=s>>row['k']
                    phase=previous_phase
                    assert (c,s)==states[angle-1]
                assert (c,s,phase)==(1<<f,0,row['initial_phase'])
                row['inverse_roundtrip_exact']=True
                row['all_data_register_bits']=4*f+18
                zero.append(row)
                print('ZERO',row,flush=True)
                break
    with (HERE/'schedule_pixel_passing.csv').open('w',newline='') as handle:
        fields=[k for k in passing[0] if k!='erase_check'] if passing else []
        writer=csv.DictWriter(handle,fields,extrasaction='ignore');writer.writeheader();writer.writerows(passing)
    report=dict(tested=tested,search='F8..16,k6..9,base=floor(ideal microsteps), power-of-two denominator1..256, reduced numerator0..D, phase in {0,D/4,D/2,3D/4,D-1}',
        pixel_passing=len(passing),minimum_fraction_bits_with_pixel_and_min6=min((v['fraction_bits'] for v in zero),default=None),
        simplest_zero_collision_by_fraction_bits=zero,collision_checked_candidates=checked,
        production_rtl_changed=False,note='Alternative numerical candidates only. Default frozen k8/F17 RTL unaffected.')
    (HERE/'schedule_search_report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k!='collision_checked_candidates'},indent=2))

if __name__=='__main__':main()
