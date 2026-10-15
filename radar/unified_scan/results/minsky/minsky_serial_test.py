"""Independent integer reference and reproducible isolated serial-datapath test."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,math,random,shutil,subprocess,sys,tempfile
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
SCAN=HERE.parents[1]
ROOT=SCAN.parents[1]


def signed(v,b):return ((v+(1<<(b-1)))%(1<<b))-(1<<(b-1))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--candidate-f15',action='store_true')
    args=parser.parse_args()
    f,k,base,p,d,phase0=(15,7,2,15,64,63) if args.candidate_f15 else (17,8,4,15,32,16)
    q=1<<f;vbits=f+2;abits=f+7
    output=HERE/('serial_f15_k7' if args.candidate_f15 else 'serial_f17_k8')
    output.mkdir(parents=True,exist_ok=True)
    stage=Path(tempfile.mkdtemp(prefix='minsky_serial_'))
    binary=ROOT/ROOT.name/'radar/sim/tools/iverilog/app/bin'
    if not binary.exists():binary=ROOT/'radar/sim/tools/iverilog/app/bin'
    c=q;s=0;x=q//2;y=q//2;rows=[];counts=[0]*8;worst=0;negative_x_points=0
    def emit(cmd,initial=None):
        nonlocal c,s,x,y
        if initial is not None:c,s,x,y=initial
        before=(c,s,x,y)
        if cmd==0:c=signed(c-(s>>k),vbits)
        elif cmd==1:s=signed(s+(c>>k),vbits)
        elif cmd==2:s=signed(s-(c>>k),vbits)
        elif cmd==3:c=signed(c+(s>>k),vbits)
        elif cmd==4:x=signed(x+c,abits)
        elif cmd==5:y=signed(y+s,abits)
        elif cmd==6:x=y=q//2
        elif cmd==7:c=q;s=0
        rows.append((cmd,int(initial is not None),*before,c,s,x,y));counts[cmd]+=1
    emit(7);emit(6);vectors=[(c,s)];phase=phase0;phases=[phase]
    for angle in range(181):
        if angle:
            n=base+(phase+p)//d;phase=(phase+p)%d
            for _ in range(n):emit(0);emit(1)
            vectors.append((c,s));phases.append(phase)
        emit(6)
        for radius in range(49):
            dx,dy=x>>f,y>>f
            assert (dx,dy)==((radius*c+q//2)//q,(radius*s+q//2)//q)
            worst=max(worst,math.hypot(dx-radius*math.cos(math.radians(angle)),dy-radius*math.sin(math.radians(angle))))
            negative_x_points+=dx<0
            if radius<48:emit(4);emit(5)
    for angle in range(180,0,-1):
        old_phase=(phase-p)%d;n=base+(old_phase+p)//d
        for _ in range(n):emit(2);emit(3)
        phase=old_phase
        assert (c,s)==vectors[angle-1] and phase==phases[angle-1]
    assert (c,s,phase)==(q,0,phase0)
    rng=random.Random(0x1324ABC)
    for _ in range(4096):
        initial=(rng.randrange(-(1<<(vbits-1)),1<<(vbits-1)),rng.randrange(-(1<<(vbits-1)),1<<(vbits-1)),
                 rng.randrange(-(1<<(abits-1)),1<<(abits-1)),rng.randrange(-(1<<(abits-1)),1<<(abits-1)))
        emit(rng.randrange(8),initial)
    (stage/'serial_vectors.txt').write_text(''.join(' '.join(map(str,row))+'\n' for row in rows))
    shutil.copy2(SCAN.parent/'rtl/minsky_serial_datapath.v',stage/'minsky_serial_datapath.v')
    shutil.copy2(HERE/'minsky_serial_tb.v',stage/'minsky_serial_tb.v')
    log=[]
    commands=[
        [str(binary/'iverilog.exe'),'-g2012',f'-Pminsky_serial_tb.FRACTION_BITS={f}',f'-Pminsky_serial_tb.ROT_SHIFT={k}','-s','minsky_serial_tb','-o','serial.vvp','minsky_serial_datapath.v','minsky_serial_tb.v'],
        [str(binary/'vvp.exe'),'serial.vvp'],
    ]
    for command in commands:
        result=subprocess.run(command,cwd=stage,capture_output=True,text=True,timeout=90)
        log.append(subprocess.list2cmdline(command)+'\n'+result.stdout+result.stderr)
        print(result.stdout,end='');print(result.stderr,end='',file=sys.stderr)
        (output/'serial_datapath.log').write_text('\n'.join(log))
        if result.returncode:raise SystemExit(result.returncode)
    spec=importlib.util.spec_from_file_location('study',HERE/'minsky_feasibility.py')
    study=importlib.util.module_from_spec(spec);spec.loader.exec_module(study)
    erase=study.erase_check(vectors,f)
    assert worst<=1 and erase['at_minimum_6']['behind_hits']==0
    report=dict(rtl_sha256=hashlib.sha256((stage/'minsky_serial_datapath.v').read_bytes()).hexdigest(),
        fraction_bits=f,rot_shift=k,base_microsteps=base,numerator=p,denominator=d,initial_phase=phase0,
        total_commands=len(rows),commands_by_code=counts,direction_vectors=181,ray_points=181*49,
        negative_x_points=negative_x_points,random_deposited_commands=4096,
        maximum_pixel_euclidean_error_px=worst,erase_check=erase,
        phase_roundtrip_exact=True,vector_roundtrip_exact=True,
        clock_pauses_and_busy_requests=True,initial_xy=q//2,
        definition='Signed high7 accumulator bits equal floor((r*coefficient+half)/2^F), including negative x. All arithmetic wraps to F+2 or F+7 bits.',
        stage=str(stage),complete_drawing_or_LE_claim=False)
    (output/'serial_datapath_report.json').write_text(json.dumps(report,indent=2)+'\n')
    shutil.copy2(stage/'serial_vectors.txt',output/'serial_vectors.txt')
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
