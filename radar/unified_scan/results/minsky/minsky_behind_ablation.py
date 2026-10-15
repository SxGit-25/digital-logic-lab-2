"""Ablation audit: relaxing behind-hit zero without changing pixel error."""
from pathlib import Path
import csv,importlib.util,json,sys
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('search',HERE/'minsky_schedule_search.py')
search=importlib.util.module_from_spec(spec);spec.loader.exec_module(search)
rows=list(csv.DictReader((HERE/'schedule_pixel_passing.csv').open()))
checked=[]
for row in rows:
    k,f,d,p,phase=[int(row[name]) for name in ('k','fraction_bits','denominator','numerator','initial_phase')]
    result,states=search.evaluate(k,f,d,p,phase)
    assert result is not None
    result['erase_check']=search.study.erase_check(states,f)
    result['phase_bits']=(d-1).bit_length()
    result['data_and_phase_register_bits']=4*f+18+result['phase_bits']
    result['data_phase_micro_register_bits']=result['data_and_phase_register_bits']+(result['base_microsteps']+1).bit_length()
    checked.append(result)
strict=next(r for r in checked if (r['fraction_bits'],r['k'],r['denominator'],r['numerator'],r['initial_phase'])==(15,7,64,15,63))
relaxed=sorted((r for r in checked if r['erase_check']['at_minimum_6']['behind_hits']>0),key=lambda r:(r['data_and_phase_register_bits'],r['data_phase_micro_register_bits'],r['fraction_bits'],r['maximum_pixel_euclidean_error_px']))
zero=sorted((r for r in checked if r['erase_check']['at_minimum_6']['behind_hits']==0),key=lambda r:(r['data_and_phase_register_bits'],r['data_phase_micro_register_bits'],r['maximum_pixel_euclidean_error_px']))
chosen=relaxed[0] if relaxed else None
report=dict(scope='Numerical ablation only; production RTL/defaults unchanged.',pixel_passing_candidates=len(checked),
    current_strict_candidate=strict,minimum_register_nonzero_behind_candidate=chosen,
    minimum_register_zero_behind_candidate=zero[0],
    minimum_fraction_bits_strict=min(r['fraction_bits'] for r in zero),
    minimum_fraction_bits_relaxed=min(r['fraction_bits'] for r in checked),
    potential_register_savings_from_relaxing_behind_zero=0,
    comparison_to_current_current_minus_nonzero_data_phase_bits=strict['data_and_phase_register_bits']-chosen['data_and_phase_register_bits'] if chosen else None,
    caveats=['Search covers F8..16, k6..9, reduced power-of-two schedules D<=256 and five selected initial phases. It does not prove global optimality beyond that search.',
             'F14/k7/2+61/256/phase255 already has zero behind hits. Its savings cannot be attributed to relaxing the behind-hit rule.',
             'Same register widths with a different phase constant can cause Quartus mapping variation. This is measured mapping variation, not guaranteed hardware savings.'],
    smallest_nonzero_options=relaxed[:12],all_candidates=checked)
(HERE/'behind_relaxation_report.json').write_text(json.dumps(report,indent=2)+'\n')
for name,r in [('strict_current',strict),('nonzero_best',chosen),('zero_minimum',zero[0])]:
 print(name,json.dumps(r,indent=2))
print('total',len(checked),'nonzero',len(relaxed),'zero',len(zero))
