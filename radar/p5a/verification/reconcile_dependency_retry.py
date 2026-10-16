"""Reconcile only the draw harness's missing-module retry; keep failed evidence."""
from pathlib import Path
import csv,hashlib,json
root=Path(__file__).resolve().parents[3]
for step in (5,6,7):
    out=root/f'radar/p5a/runs/p5r_step{step}_full'
    retry=root/f'radar/p5a/runs/p5r_step{step}_draw_dependency_retry'
    rows=list(csv.DictReader((out/'status.csv').open(encoding='utf-8-sig')))
    assert len(rows)==20,(step,len(rows))
    assert [r['Suite'] for r in rows if r['Pass']!='True']==['draw'],step
    assert (retry/'PASS.txt').exists(),retry
    hashes=json.loads((out/'tests_sha256.json').read_text())
    assert all(hashlib.sha256((root/f).read_bytes()).hexdigest()==h for f,h in hashes.items())
    retry_hashes={r['File']:r['Hash'] for r in csv.DictReader((retry/'sources_sha256.csv').open(encoding='utf-8-sig'))}
    for name in ('radar_lcd_micro.v','p5_ui_columns.v'):
        assert retry_hashes[name].lower()==hashlib.sha256((out/'source_snapshot'/name).read_bytes()).hexdigest()
    note=(f'PASS all 20 original regressions after draw dependency retry.\n'
          f'Original failed compilation is retained in status.csv. No test assertions changed.\n'
          f'19 original tests passed; draw re-run passed from the same RTL snapshot: {retry}\n')
    (out/'PASS.txt').write_text(note,encoding='utf-8')
    for r in rows:
        if r['Suite']=='draw':r.update(Exit='0',Pass='True',Evidence=str(retry))
    with (out/'status_after_dependency_retry.csv').open('w',newline='',encoding='utf-8-sig') as f:
        writer=csv.DictWriter(f,fieldnames=rows[0]);writer.writeheader();writer.writerows(rows)
    print(f'PASS stage {step}, all 20 verified, unchanged assertions and RTL hashes')
