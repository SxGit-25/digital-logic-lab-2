"""Parallel unshortened regressions, all consuming the same retained RTL snapshot."""
from pathlib import Path
import argparse, concurrent.futures, csv, hashlib, json, shutil, subprocess, time

ROOT = Path(__file__).resolve().parents[3]
p=argparse.ArgumentParser()
p.add_argument('--run-name',required=True)
p.add_argument('--source-dir',type=Path,default=ROOT/'radar/rtl')
p.add_argument('--jobs',type=int,default=4)
p.add_argument('--step1',action='store_true')
a=p.parse_args()
out=ROOT/'radar/p5a/runs'/a.run_name
out.mkdir(parents=True,exist_ok=False)
snapshot=out/'source_snapshot';snapshot.mkdir()
for f in a.source_dir.glob('*.v'): shutil.copy2(f,snapshot/f.name)
assert list(snapshot.glob('*.v')),'Source directory must contain .v production RTL'
(out/'sources_sha256.json').write_text(json.dumps({f.name:hashlib.sha256(f.read_bytes()).hexdigest() for f in sorted(snapshot.glob('*.v'))},indent=2))
test_files=list((ROOT/'radar/sim').glob('tb_*.v'))+list((ROOT/'radar/sim/unified_scan').glob('tb_*.v'))+list(Path(__file__).parent.glob('*.v'))
test_files += [ROOT/'radar/sim/unified_scan/minsky_draw_fixtures.py',Path(__file__).with_name('prepare_step1.py')]
test_snapshot=out/'test_snapshot';test_snapshot.mkdir()
test_hashes={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in test_files}
for f in test_files:
    dest=test_snapshot/f.relative_to(ROOT);dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(f,dest)
(out/'tests_sha256.json').write_text(json.dumps(test_hashes,indent=2))
tests=[]
for name in ('servo_pwm','ultrasonic','radar_ctrl','radar_top','alarm_ctrl','counter_equivalence'):
    tests.append(('original','original_'+name))
tests += [('units',s) for s in ('tb_global_budget','tb_alarm_global','tb_switch_pair')]
tests += [(s,s) for s in ('measurement','display','matrix','top','draw')]
tests += [('scan',s) for s in ('scan_control','scan_production_basic','scan_production_continuous')]
if a.step1: tests.extend(('step1','step1_'+mode) for mode in ('basic','continuous','pending'))

def run(case):
    suite,name=case; run_name=a.run_name+'_'+name
    script=ROOT/('radar/p5a/verification/run_step1.ps1' if suite=='step1' else 'radar/p5a/run_regression.ps1')
    args=['pwsh','-NoProfile','-ExecutionPolicy','Bypass','-File',str(script),'-RunName',run_name,'-SourceDir',str(snapshot)]
    if suite!='step1':args+=['-Suites',suite,'-OnlyTest',name]
    else:args+=['-Modes',name.removeprefix('step1_')]
    started=time.monotonic()
    with (out/(name+'.runner.log')).open('w') as log:
        rc=subprocess.run(args,stdout=log,stderr=subprocess.STDOUT,cwd=ROOT).returncode
    evidence=ROOT/'radar/p5a/runs'/run_name
    return dict(Suite=name,Exit=rc,Pass=rc==0 and (suite=='step1' or (evidence/'PASS.txt').exists()),Seconds=round(time.monotonic()-started,2),Evidence=str(evidence))

statuses=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=max(1,a.jobs)) as pool:
    for future in concurrent.futures.as_completed([pool.submit(run,test) for test in tests]):
        result=future.result()
        statuses.append(result)
        with (out/'status.csv').open('w',newline='',encoding='utf-8') as f:
            w=csv.DictWriter(f,fieldnames=list(result));w.writeheader();w.writerows(statuses)
        print(json.dumps(result),flush=True)
if any(not r['Pass'] for r in statuses):raise SystemExit(1)
if any(hashlib.sha256((ROOT/f).read_bytes()).hexdigest()!=digest for f,digest in test_hashes.items()):
    raise SystemExit('Test sources changed during stage; frozen evidence retained; rerun affected tests')
(out/'PASS.txt').write_text('PASS all original regressions and selected new tests from one source snapshot\n')
