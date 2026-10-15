"""Exact integer arithmetic audit; no RTL files or original tests are changed."""
from pathlib import Path
import csv
import json
import math
import re
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "radar/unified_scan/results/bcd_experiment"
OUT.mkdir(parents=True, exist_ok=True)


def blank():
    return dict(samples=0, legacy_valid_samples=0, both_valid_samples=0,
                legacy_only_valid=0, experiment_only_valid=0,
                error_histogram={}, raw_error_over_legacy_valid={},
                radius_bin_disagreements=0, radius_validity_disagreements=0,
                level_disagreements=0, examples=[])


def add_hist(target, x):
    if not x.size:
        return
    lo, hi = int(x.min()), int(x.max())
    bins = np.bincount((x - lo).ravel(), minlength=hi-lo+1)
    for i, count in enumerate(bins):
        if count:
            key = str(i+lo)
            target[key] = target.get(key, 0) + int(count)


def audit(s, n, phase, raw, ref, q):
    rv = (raw >= 118) & (raw <= 23529)
    qv = (q >= 20) & (q <= 4000)
    both = rv & qv
    s["samples"] += int(rv.size)
    s["legacy_valid_samples"] += int(rv.sum())
    s["both_valid_samples"] += int(both.sum())
    s["legacy_only_valid"] += int((rv & ~qv).sum())
    s["experiment_only_valid"] += int((qv & ~rv).sum())
    delta = np.broadcast_to(q-ref, rv.shape)
    add_hist(s["error_histogram"], delta[both])
    add_hist(s["raw_error_over_legacy_valid"], delta[rv])
    s["radius_bin_disagreements"] += int((both & (np.minimum(q//25,48) != np.minimum(ref//25,48))).sum())
    s["radius_validity_disagreements"] += int((both & ((q<=1200) != (ref<=1200))).sum())
    lev_q = (q<800).astype(np.int8)+(q<600)+(q<400)+(q<200)+1
    lev_r = (ref<800).astype(np.int8)+(ref<600)+(ref<400)+(ref<200)+1
    s["level_disagreements"] += int((both & (lev_q != lev_r)).sum())
    if len(s["examples"]) < 8:
        indices=np.argwhere(rv & ((delta!=0) | ~qv))
        for row, col in indices[:8-len(s["examples"])]:
            s["examples"].append(dict(width_clocks=int(n[row,0]),
                                      echo_start_phase=int(phase[0,col]),
                                      legacy_raw_us=int(raw[row,col]),
                                      legacy_mm=int(ref[row,col]),
                                      experiment_mm=int(np.broadcast_to(q, rv.shape)[row,col]),
                                      experiment_valid=bool(np.broadcast_to(qv,rv.shape)[row,col])))


def finish(s):
    h={int(k):v for k,v in s["error_histogram"].items()}
    total=sum(h.values())
    s["max_abs_error_mm_when_both_valid"]=max(map(abs,h),default=0)
    s["mean_error_mm_when_both_valid"]=sum(k*v for k,v in h.items())/total
    s["rms_error_mm_when_both_valid"]=math.sqrt(sum(k*k*v for k,v in h.items())/total)
    s["error_distribution_percent_when_both_valid"]={str(k):100*v/total for k,v in sorted(h.items())}
    return s


def parse_quartus():
    rows=[]
    for variant in ("legacy","optimized","fractional","integer294"):
        p=OUT/"quartus"/variant
        fit=(p/f"bcd_measurement_{variant}.fit.rpt").read_text(errors="replace")
        sta=(p/f"bcd_measurement_{variant}.sta.summary").read_text(errors="replace")
        le=int(re.search(r"Total logic elements\s*;\s*(\d+)",fit)[1])
        registers=int(re.search(r"Total registers\s*;\s*(\d+)",fit)[1])
        setup=float(re.search(r"Setup 'clk'\s+Slack\s*:\s*([-\d.]+)",sta)[1])
        hold=float(re.search(r"Hold 'clk'\s+Slack\s*:\s*([-\d.]+)",sta)[1])
        rows.append(dict(variant=variant,fitter_le=le,registers=registers,
                         setup_slack_ns=setup,hold_slack_ns=hold))
    with (OUT/"quartus_comparison.csv").open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=rows[0]);w.writeheader();w.writerows(rows)
    return rows


def main():
    stats={name:blank() for name in ("fractional_rounded","integer294_rounded","fractional_floor")}
    # Every physical width 20 ns..30 ms, and all 50 possible 1-MHz sampling
    # phases. Count edges strictly between synchronized rising/falling edges.
    phase=np.arange(50,dtype=np.int64)[None,:]
    for first in range(1,1500001,2048):
        n=np.arange(first,min(first+2048,1500001),dtype=np.int64)[:,None]
        raw=(phase+n-1)//50
        ref=(17*raw+50)//100
        values=((17*n+2500)//5000,(n+147)//294,(17*n)//5000)
        for s,q in zip(stats.values(),values):
            audit(s,n,phase,raw,ref,q)
    # Coupled global tick phases repeat every 5000 clocks: the fractional
    # divider and the 1-MHz divider run from the same 50-MHz reset origin.
    free=blank();phase=np.arange(5000,dtype=np.int64)[None,:]
    for first in range(1,30001,64):
        width=np.arange(first,min(first+64,30001),dtype=np.int64)[:,None]
        n=width*50
        raw=(phase+n-1)//50-phase//50
        ref=(17*raw+50)//100
        q=(17*(phase+n-1))//5000-(17*phase)//5000
        audit(free,n,phase,raw,ref,q)
    stats["fractional_free_running_integer_us_widths"]=free
    data=dict(baseline="f4507a8",clock_hz=50000000,
              reset_phase_domain="All N=1..1500000 clock widths x all 50 microsecond-tick phases (75 million cases per policy)",
              free_phase_domain="Widths 1..30000 integer us x all 5000 coupled global start phases (150 million cases)",
              fractional_rate_hz=170000,integer294_rate_hz=50000000/294,
              integer294_scale_error_ppm=(5000/4998-1)*1e6,
              fractional_interval_clocks={"294":15,"295":2},
              fractional_phase_preload_rounded=2517,integer_phase_preload_rounded=148,
              results={name:finish(s) for name,s in stats.items()},quartus=parse_quartus())
    (OUT/"numerical_comparison.json").write_text(json.dumps(data,indent=2))
    for name,s in data["results"].items():
        print(name,"max_error_mm=",s["max_abs_error_mm_when_both_valid"],
              "distribution=",s["error_distribution_percent_when_both_valid"],
              "legacy_only_valid=",s["legacy_only_valid"],"new_only_valid=",s["experiment_only_valid"])
    print("PASS numeric audit; full JSON and fitted-block comparison CSV saved")


if __name__=="__main__":
    main()
