"""Verify checkpoint sequence, fitted production inputs and exported firmware."""
from pathlib import Path
import hashlib,json,re,subprocess
root=Path(__file__).resolve().parents[3]
here=Path(__file__).resolve().parent
checkpoints=[json.loads((here/f'step{i}/checkpoint.json').read_text(encoding='utf-8')) for i in range(1,8)]
final=checkpoints[2]
assert final['fitter_success'] and final['le']<=1270 and final['setup_ns']>0 and final['hold_ns']>0
assert final['setup_ns']>=1
for item in checkpoints:
    assert 'PASS' in (root/item['regression_pass']).read_text(encoding='utf-8-sig')
    assert sum(m['le_self'] for m in item['modules'])==item['le']
    assert (here/'pofs'/item['pof']).exists()
for item in checkpoints[3:]:
    assert item['status']=='reverted' and item['setup_delta_ns']==0
    attempts=item['attempts']
    assert all(not t['fitter_success'] and t['le_required']>1270 for t in attempts)
    prefix=f'p5r_step{item["step"]}_'
    assert all(any(t['build']==prefix+('initial' if seed==1 else f'seed{seed}') or
                   t['build']==prefix+f'special_seed{seed}' for t in attempts) for seed in range(1,9))
    assert (here/'pofs'/item['pof']).read_bytes()==(here/'pofs'/final['pof']).read_bytes()
    if item['step']>=5:
        assert all(any(t['build']==prefix+f'special_seed{seed}' for t in attempts) for seed in range(1,9))
        assert all(not t['fitter_success'] for t in attempts)
stage=root/'radar/unified_scan/results'/final['build']/'bcd/source'
for path in (stage/'rtl').glob('*.v'):
    production=root/'radar/rtl'/path.name
    assert path.read_bytes()==production.read_bytes(),production
assert (stage/'lcd_p4/radar_unified_variants.v').read_bytes()==(root/'radar/unified_scan/radar_unified_variants.v').read_bytes()
for suffix in ('mif','mem','hex'):
    assert (stage/f'lcd_p4/background.{suffix}').read_bytes()==(root/f'radar/unified_scan/background.{suffix}').read_bytes()
qsf=(root/'radar/unified_scan/radar_unified_bcd.qsf').read_text()
assert (stage/'lcd_p4/radar_unified_bcd.qsf').read_bytes()==(root/'radar/unified_scan/radar_unified_bcd.qsf').read_bytes()
for name in ('radar_unified_bcd.sdc','radar_unified_ufm.sdc'):
    assert (stage/'lcd_p4'/name).read_bytes()==(root/'radar/unified_scan'/name).read_bytes()
assert re.search(r'SEED\s+1\b',qsf) and 'P5_UFM 1' in qsf and 'P5_INVERT 1' in qsf
assert 'P5_BEAM 1' not in qsf and 'P5_DIGITS 1' not in qsf and 'P5_LEVEL 1' not in qsf
postfit=json.loads((here/'step3/postfit_final/postfit_summary.json').read_text())
assert postfit['CDC_PASS']
for name,row in postfit.items():
    if isinstance(row,dict):assert row['setup_delta']==row['hold_delta']==0
baseline=here/'pofs/step0_original_SW6_readback_1089LE.pof'
assert hashlib.sha256(baseline.read_bytes()).hexdigest()=='709218e16d4b0618bd6656a9ba09ba896add2ad8b9cbeaec44ec7c943fa4dfd3'
tags=[]
for i in range(1,8):
    tag=f'p5-step{i}'
    sha=subprocess.check_output(['git','rev-parse',tag],cwd=root,text=True).strip()
    path=f'radar/p5a/restart/step{i}/checkpoint.json'
    at_tag=json.loads(subprocess.check_output(['git','show',f'{tag}:{path}'],cwd=root))
    assert at_tag['step']==i
    if tags:subprocess.run(['git','merge-base','--is-ancestor',tags[-1]['commit'],sha],cwd=root,check=True)
    tags.append(dict(tag=tag,commit=sha))
for item in checkpoints[3:]:
    prefix=f'p5r_step{item["step"]}_'
    for seed in range(1,9):
        name=(f'special_seed{seed}' if item['step']>=5 else 'initial' if seed==1 else f'seed{seed}')
        report=(root/'radar/unified_scan/results'/(prefix+name)/'bcd/radar_unified_bcd.fit.rpt').read_text(errors='replace')
        assert re.search(r'Fitter Initial Placement Seed\s*;\s*'+str(seed)+r'\s*;',report),(item['step'],seed)
record=dict(result='PASS',final_step=3,le=final['le'],setup_ns=final['setup_ns'],hold_ns=final['hold_ns'],seed=1,
            tags=tags,pofs=[dict(name=f.name,sha256=hashlib.sha256(f.read_bytes()).hexdigest()) for f in sorted((here/'pofs').glob('*.pof'))])
(here/'delivery/final_verification.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS: 7 checkpoints/tags, all regression records, production/build input identity, fitting gates, CDC, baseline and rollback POFs')
