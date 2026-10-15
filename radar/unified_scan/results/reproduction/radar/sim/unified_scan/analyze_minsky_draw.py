from pathlib import Path
import csv, hashlib, json, re

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'radar/unified_scan/results/draw_sim'

def main():
    results=[]
    for name in ('compact_f15','baseline_f15','baseline_f17_smoke'):
        p=OUT/name
        if not (p/'simulation.log').exists():continue
        log=(p/'simulation.log').read_text(errors='replace')
        reference=json.loads((p/'scenario_reference.json').read_text())
        rows=list(csv.DictReader((p/'busy_walltime.csv').open()))
        for row in rows:
            for k,v in row.items():row[k]=int(v)
        endpoints=[r for r in rows if r['erase_rays']==11]
        ordinary=[r for r in rows if r['erase_rays']!=11]
        failures=[r for r in rows if r['busy_ns']>=1000000]
        result=dict(variant=name,full_scan=not reference['smoke'],
            functional_pass='PASS_FUNCTIONAL' in log,
            completed_requests=len(rows),expected_requests=len(reference['scenarios']),
            strict_under_1ms_pass=not failures,
            deadline_failure_count=len(failures),
            maximum_busy_ns=max((r['busy_ns'] for r in rows),default=None),
            maximum_ordinary_busy_ns=max((r['busy_ns'] for r in ordinary),default=None),
            maximum_endpoint_busy_ns=max((r['busy_ns'] for r in endpoints),default=None),
            endpoint_measurements=endpoints,deadline_failures=failures,
            final_dropped=rows[-1]['dropped'] if rows else None,
            expected_rmw_pixels=sum(s['rmw_pixels'] for s in reference['scenarios']),
            expected_a_rays=sum(s['erase_rays'] for s in reference['scenarios']),
            expected_b_rays=len(reference['scenarios']))
        results.append(result)
    images={}
    for image in ('full_scan.pbm','multiple_targets_turnaround.pbm'):
        a=OUT/'compact_f15'/image;b=OUT/'baseline_f15'/image
        if a.exists() and b.exists():
            images[image]=hashlib.sha256(a.read_bytes()).hexdigest()==hashlib.sha256(b.read_bytes()).hexdigest()
    summary=dict(results=results,compact_and_baseline_f15_image_identical=images,
        configured_endpoint_bus_only_lower_bound=dict(minimum_rmw_pixels=443,
            cycles_per_rmw_without_master_handshake=6*(4+6+6)+2*(20+4+10+6),
            minimum_cycles=443*176,minimum_ns=443*176*20,
            includes_serial_datapath_or_vector_work=False),
        protocol_model='Unmodified radar/sim/lcd/st7565_model.v; complete init and 1056-byte clear, physical bus timing/read dummy semantics',
        functional_oracle='Minsky agent minsky_schedule_search.evaluate; all accepted RMW address/data/order, every canonical vector, all 1056 RAM bytes after each request')
    (OUT/'summary.json').write_text(json.dumps(summary,indent=2))
    with (OUT/'status.csv').open('w',newline='') as f:
        writer=csv.writer(f);writer.writerow(['variant','functional_pass','strict_under_1ms_pass','completed_requests','deadline_failures','max_busy_ns','max_ordinary_busy_ns','max_endpoint_busy_ns'])
        for r in results:
            writer.writerow([r['variant'],r['functional_pass'],r['strict_under_1ms_pass'],r['completed_requests'],r['deadline_failure_count'],r['maximum_busy_ns'],r['maximum_ordinary_busy_ns'],r['maximum_endpoint_busy_ns']])
    print(json.dumps(dict(results=[{k:v for k,v in r.items() if k not in ('endpoint_measurements','deadline_failures')} for r in results],images_identical=images),indent=2))

if __name__=='__main__':main()
