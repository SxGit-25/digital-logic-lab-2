"""Numerical feasibility audit only. Does not read or write production RTL."""
from pathlib import Path
import math,json,csv,itertools

HERE=Path(__file__).resolve().parent
DEG=math.pi/180
IDEAL=[(math.cos(a*DEG),math.sin(a*DEG)) for a in range(181)]


def run_vector(f, terms, microsteps=1, schedule=None):
    q=1<<f;c=q;s=0;states=[(c,s)]
    def t(v):return sum(sign*(v>>k) for sign,k in terms)
    for a in range(1,181):
        n=microsteps if schedule is None else schedule(a)
        for _ in range(n):
            c-=t(s)
            s+=t(c)
        states.append((c,s))
    forward_last=(c,s)
    for a in range(180,0,-1):
        n=microsteps if schedule is None else schedule(a)
        for _ in range(n):
            s-=t(c)
            c+=t(s)
        assert (c,s)==states[a-1],(f,terms,microsteps,a)
    assert (c,s)==(q,0)
    worst=0;max_coord=0;where=None;max_vector=0;angle_error=0;max_integer=0
    for a,(c,s) in enumerate(states):
        max_integer=max(max_integer,abs(c),abs(s))
        actual_angle=math.degrees(math.atan2(s,c))
        error=(actual_angle-a+180)%360-180
        angle_error=max(angle_error,abs(error))
        ic,iss=IDEAL[a]
        max_vector=max(max_vector,48*math.hypot(c/q-ic,s/q-iss))
        for r in range(49):
            dx=(r*c+q//2)//q;dy=(r*s+q//2)//q
            e=math.hypot(dx-r*ic,dy-r*iss)
            coord=max(abs(dx-int(math.floor(r*ic+0.5))),abs(dy-int(math.floor(r*iss+0.5))))
            max_coord=max(max_coord,coord)
            if e>worst:worst=e;where=[a,r,dx,dy]
    signed_bits=max_integer.bit_length()+1
    angle45=math.degrees(math.atan2(states[45][1],states[45][0]))
    end=[]
    for a in (0,45,90,180):
        c,s=states[a]
        end.append(dict(angle=a,c=c,s=s,actual_angle_degrees=math.degrees(math.atan2(s,c))))
    return dict(fraction_bits=f,signed_register_bits=max(f+2,signed_bits),
        terms=terms,microsteps=microsteps,angle_after_45_steps=angle45,
        maximum_direction_angle_error_degrees=angle_error,
        maximum_unrounded_vector_error_px=max_vector,maximum_pixel_euclidean_error_px=worst,
        maximum_axis_error_vs_rounded_pixels=max_coord,worst_pixel=where,
        meets_one_pixel=worst<=1.0,inverse_roundtrip_exact=True,endpoints=end),states


def erase_check(states,f):
    q=1<<f
    points={(a,r):((r*c+q//2)//q,(r*s+q//2)//q)
            for a,(c,s) in enumerate(states) for r in range(49)}
    for minimum in range(6,49):
        by={}
        for a in range(181):
            for raw in range(49):by.setdefault(points[a,max(minimum,raw)],[]).append((a,raw))
        hits=0;example=None
        for k in range(181):
            for up in (False,True):
                future=set();position=k;direction=up
                for _ in range(10):
                    if position==180:direction=False
                    elif position==0:direction=True
                    position+=1 if direction else -1;future.add(position)
                erase=(range(170,181) if k==180 and not up else
                       range(0,11) if k==0 and up else (k+10,) if up and k<=170 else
                       (k-10,) if not up and k>=10 else ())
                for ea in erase:
                    for r in range(minimum,49):
                        if r in (16,32,48):continue
                        for a,raw in by.get(points[ea,r],()):
                            if ((up and a<k) or (not up and a>k)) and a not in future:
                                hits+=1
                                if example is None:example=[k,int(up),ea,r,a,raw]
        if minimum==6:at6=dict(minimum_radius=6,behind_hits=hits,example=example)
        if not hits:return dict(at_minimum_6=at6,first_zero_minimum=minimum)
    return dict(at_minimum_6=at6,first_zero_minimum=None)


def main():
    single=[]
    for f in range(33):
        for k in range(33):
            result,_=run_vector(f,[(1,k)])
            single.append(result)
    with (HERE/'single_shift_scan.csv').open('w',newline='') as h:
        fields=['fraction_bits','signed_register_bits','microsteps','angle_after_45_steps',
                'maximum_direction_angle_error_degrees','maximum_pixel_euclidean_error_px',
                'maximum_unrounded_vector_error_px','meets_one_pixel','inverse_roundtrip_exact']
        w=csv.DictWriter(h,['shift_k']+fields);w.writeheader()
        for row in single:w.writerow(dict(shift_k=row['terms'][0][1],**{k:row[k] for k in fields}))
    best=min(single,key=lambda v:v['maximum_pixel_euclidean_error_px'])
    print('Single shift best',best,flush=True)
    candidates=[]
    for name,terms,n,schedule in [
        ('single_k6',[(1,6)],1,None),
        ('scheduled_k8_4_plus_15_32',[(1,8)],1,lambda a:4+(16+15*a)//32-(16+15*(a-1))//32),
        ('two_shift_nearest',[(1,6),(1,9)],1,None),
        ('three_shift_correction',[(1,6),(1,9),(-1,13)],1,None),
        ('microstep_9_k9',[(1,9)],9,None),
        ('microstep_71_k12',[(1,12)],71,None),
        ('microstep_143_k13',[(1,13)],143,None),
        ('fractional_71_72_k12',[(1,12)],1,lambda a:round(a*DEG/(2*math.asin(2**-12/2)))-round((a-1)*DEG/(2*math.asin(2**-12/2)))),
    ]:
        options=[]
        for f in (range(12,19) if name=='scheduled_k8_4_plus_15_32' else range(8,29)):
            result,states=run_vector(f,terms,n,schedule)
            result['name']=name;options.append(result)
            if name=='scheduled_k8_4_plus_15_32' or f in (16,20,24,28) or (result['meets_one_pixel'] and not any(x['meets_one_pixel'] for x in options[:-1])):
                result['erase_check']=erase_check(states,f)
        best_option=min(options,key=lambda v:v['maximum_pixel_euclidean_error_px'])
        first_pass=next((v for v in options if v['meets_one_pixel']),None)
        candidates.append(dict(name=name,requires_specification_change=name!='single_k6',
            best=best_option,minimum_passing_fraction_bits=first_pass['fraction_bits'] if first_pass else None,
            tested=options))
        print(name,'best error',best_option['maximum_pixel_euclidean_error_px'],
              'first F',first_pass['fraction_bits'] if first_pass else None,flush=True)
    report=dict(scope='Pure numerical feasibility study; production RTL frozen',
        exact_phase_degrees={str(k):math.degrees(2*math.asin(2**-k/2)) for k in range(9)},
        tested_single_shift=dict(fraction_bits=list(range(33)),shift_k=list(range(33)),
            combinations=len(single),passing=sum(r['meets_one_pixel'] for r in single),best=best),
        ideal_one_degree_coefficient=2*math.sin(DEG/2),candidates=candidates,
        notes=['Pixel error is Euclidean against continuous ideal r*cos/sin at every integer angle 0..180 and radius 0..48.',
               'Signed arithmetic right shift and unlimited intermediate precision; signed_register_bits bounds show absence of overflow.',
               'Backward step is s_old=s-(c>>k), c_old=c+(s_old>>k); generalized exactly for shift-sum map.',
               'No candidate is asserted to satisfy exactly 45 degrees at step45; actual angle is reported.',
               'Three-shift and microstep/scheduled alternatives alter the requested single-shift per-degree update and require user confirmation.'])
    (HERE/'minsky_report.json').write_text(json.dumps(report,indent=2)+'\n')


def audit_phase():
    report=json.loads((HERE/'minsky_report.json').read_text())
    candidate=next(c for c in report['candidates'] if c['name']=='scheduled_k8_4_plus_15_32')
    for row in candidate['tested']:
        f=row['fraction_bits'];q=1<<f
        _,states=run_vector(f,[(1,8)],1,lambda a:4+(16+15*a)//32-(16+15*(a-1))//32)
        phase=16;c=q;s=0;phases=[phase]
        for a in range(1,181):
            n=4+(phase+15)//32;phase=(phase+15)%32
            for _ in range(n):c-=s>>8;s+=c>>8
            assert (c,s)==states[a]
            phases.append(phase)
        for a in range(180,0,-1):
            previous_phase=(phase-15)%32;n=4+(previous_phase+15)//32
            for _ in range(n):s-=c>>8;c+=s>>8
            phase=previous_phase
            assert phase==phases[a-1] and (c,s)==states[a-1]
        assert (phase,c,s)==(16,q,0)
        row.update(phase_forward_reverse_exact=True,phase_at_180=phases[180],phase_after_reverse=phase,
            minimum_vector_magnitude=min(math.hypot(c,s)/q for c,s in states),
            maximum_vector_magnitude=max(math.hypot(c,s)/q for c,s in states),
            maximum_magnitude_error_px_at_radius_48=48*max(abs(math.hypot(c,s)/q-1) for c,s in states))
    real=[]
    for k in range(33):
        h=2**-k;c=1.;s=0.;worst=0.
        for a in range(181):
            worst=max(worst,48*math.hypot(c-math.cos(a*DEG),s-math.sin(a*DEG)))
            c-=h*s;s+=h*c
        real.append(dict(k=k,maximum_unrounded_vector_error_px=worst))
    report['single_shift_wide_precision_proof']=dict(real_arithmetic_scan=real,
        best=min(real,key=lambda r:r['maximum_unrounded_vector_error_px']),
        quantization_vector_error_bound_px_F_ge_32=48*180*math.sqrt(15)/(1<<32),
        argument='Invariant c*c+s*s-h*c*s bounds every A^n Euclidean norm by sqrt(3), h=2^-k<=1. Each floor update injects <=sqrt(5)/Q vector error. For N<=180 the error is <=N*sqrt(15)/Q. Larger F cannot correct the real-oscillator angle mismatch. For k>=33, real rotation over 180 steps is negligible; for F<=32 it is exactly stuck at (1,0).')
    (HERE/'minsky_report.json').write_text(json.dumps(report,indent=2)+'\n')
    (HERE/'scheduled_k8_report.json').write_text(json.dumps(candidate['tested'],indent=2)+'\n')

if __name__=='__main__':
    main()
    audit_phase()
