"""Gate the delivery export on retained build and regression evidence."""
from pathlib import Path
import csv
import hashlib
import json
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
BUILD = ROOT / 'radar/unified_scan/results/beam_min_byte_a/bcd'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text(path):
    data = path.read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig').replace('\r\n', '\n')


def main():
    assert subprocess.check_output(['git', 'branch', '--show-current'], cwd=ROOT).decode().strip() == 'beam-min'
    assert subprocess.check_output(['git', 'rev-parse', 'delivery-1253'], cwd=ROOT).decode().strip() == '567ee43e44f08fa5eb753e78231c5cc27bd4be28'
    frozen_rel = 'radar/p5a/restart/pofs/step3_A0_pending_snapshot_syncSW7_UFM_alarmInverse_1253LE.pof'
    frozen = ROOT / frozen_rel
    frozen_hash = '67332205e468962a8a7a9a475d2eab27594de9549e2a1dde77653211edc4f50a'
    assert digest(frozen) == frozen_hash
    assert subprocess.check_output(['git', 'show', f'delivery-1253:{frozen_rel}'], cwd=ROOT) == frozen.read_bytes()

    # Compare all actual Fitter inputs against the retained input manifest.
    manifest = list(csv.DictReader(text(BUILD/'source_sha256.csv').splitlines()))
    for row in manifest:
        assert digest(BUILD/'source'/row['File']) == row['SHA256'].lower(), row
    source_hashes = {}
    for f in (BUILD/'source/rtl').glob('*.v'):
        current = ROOT/'radar/rtl'/f.name
        assert digest(current) == digest(f), f.name
        source_hashes[str(current.relative_to(ROOT))] = digest(current)
    wrapper = ROOT/'radar/unified_scan/radar_unified_variants.v'
    assert digest(wrapper) == digest(BUILD/'source/lcd_p4'/wrapper.name)
    source_hashes[str(wrapper.relative_to(ROOT))] = digest(wrapper)
    for name in ['radar_unified_bcd.qsf', 'radar_unified_ufm.sdc']:
        current = ROOT/'radar/unified_scan'/name
        assert digest(current) == digest(BUILD/'source/lcd_p4'/name), name
        source_hashes[str(current.relative_to(ROOT))] = digest(current)
    qsf = text(BUILD/'source/lcd_p4/radar_unified_bcd.qsf')
    assert re.search(r'SEED\s+1\s*$', qsf, re.M)
    assert '.ENABLE_READBACK(1)' in text(wrapper).split('module radar_unified_bcd_top', 1)[1].split('endmodule', 1)[0]
    for flag in ['P5_UFM', 'P5_INVERT', 'P5_BEAM', 'P5_UFM_BYTE']:
        assert re.search(rf'-name\s+{flag}\s+1\s*$', qsf, re.M), flag
    assert 'Fitter was successful' in text(BUILD/'radar_unified_bcd.fit.rpt')
    assert '1,270 / 1,270' in text(BUILD/'radar_unified_bcd.fit.summary')
    sta = text(BUILD/'radar_unified_bcd.sta.summary')
    assert "Setup 'clk'\nSlack : 2.994" in sta
    assert "Hold 'clk'\nSlack : 1.078" in sta

    post = json.loads(text(HERE/'postfit/postfit_summary.json'))
    assert post['CDC_PASS']
    assert all(v['setup_delta'] == v['hold_delta'] == 0 for v in post.values() if isinstance(v, dict))
    ufm = json.loads(text(HERE/'pof_verified/verification.json'))
    pof = BUILD/'radar_unified_bcd.pof'
    assert ufm['pass'] and ufm['compared_words'] == 512 and ufm['mismatch_count'] == 0
    assert ufm['official_svf_crosscheck']['all_words_match_direct_pof_payload']
    assert digest(pof) == ufm['pof_sha256']

    regress = ROOT/'radar/p5a/runs/beam_min_a_full'
    assert (regress/'PASS.txt').is_file()
    rows = list(csv.DictReader(text(regress/'status.csv').splitlines()))
    assert len(rows) == 20 and all(r['Pass'] == 'True' and r['Exit'] == '0' for r in rows)
    regression_hashes = json.loads(text(regress/'sources_sha256.json'))
    for f in (ROOT/'radar/rtl').glob('*.v'):
        assert regression_hashes[f.name] == digest(f), f.name

    full = HERE/'test/render/runs/byte_a_full'
    timing = json.loads(text(full/'timing_summary.json'))
    for mode in ['basic', 'continuous']:
        d = full/mode
        case = json.loads(text(d/'reference.json'))
        assert case['full_roundtrips'] == 3 and case['beam'] and len(case['requests']) == 1091
        assert '1091 requests, 1152096 bytes' in text(d/'comparison.log')
        log = text(d/'simulation.log')
        assert 'BEAM_REMOVE_PASS comparisons=1091' in log
        assert 'INTEGER_CHANGE_PASS unique_radial_checks=106918 full_radius_6_to_48=1' in log
        assert f'PASS render mode={int(mode=="continuous")} requests=1091' in log
        assert timing[mode]['requests'] == 1091
        hashes = {r['File']: r['Hash'].lower() for r in csv.DictReader(text(d/'sources_sha256.csv').splitlines())}
        for f in (BUILD/'source/rtl').glob('*.v'):
            assert hashes[f.name] == digest(f), (mode, f.name)
    for mode in ['basic', 'continuous']:
        assert f'PASS busy_stop mode={int(mode=="continuous")} phases=5 RAM_bytes_compared=10560' in text(HERE/f'test/render/runs/byte_a_busy_stop/{mode}/simulation.log')
    assert 'PASS UFM byte words512' in text(HERE/'test/ufm_a/simulation.log')
    assert 'PASS UFM words=1025' in text(HERE/'test/legacy_ufm/simulation.log')
    alarm = HERE/'test/alarm/runs/beam_byte_a_alarm'
    assert 'CONCURRENT_ALARM_PASS frames=2 Python_expected_bytes=2112' in text(alarm/'simulation.log')
    assert 'PASS alarm_inverse commands=9' in text(alarm/'simulation.log')
    assert 'PASS' in text(HERE/'test/top_quiesce_results/simulation.log')

    dest = HERE/'delivery'
    dest.mkdir(exist_ok=True)
    target = dest/'beam_min_full_r6-48_XOR_UFM8_keepInverse_1270LE.pof'
    shutil.copy2(pof, target)
    assert digest(target) == digest(pof)
    # The preview is an actual verified RAM frame, not a separate drawing.
    from PIL import Image
    actual = bytes(int(v, 16) for v in text(full/'basic/actual.mem').split())
    case = json.loads(text(full/'basic/reference.json'))['requests'][52]
    assert case['angle'] == 52
    frame = actual[52*1056:53*1056]
    image = Image.new('RGB', (128, 64), (205, 220, 180))
    for y in range(64):
        for x in range(128):
            if frame[(y//8)*132+x] & (1 << (y%8)):
                image.putpixel((x, y), (25, 43, 30))
    image.resize((1024, 512), Image.Resampling.NEAREST).save(dest/'verified_frame_052.png')
    record = dict(branch='beam-min', seed=1, le=1270, setup_ns=2.994, hold_ns=1.078,
                  resource_step='a only; inverse retained; b/c not applied',
                  frozen_pof=frozen_rel, frozen_sha256=frozen_hash,
                  new_pof=str(target.relative_to(ROOT)), new_sha256=digest(target),
                  hardware_programmed=False, source_hashes=source_hashes,
                  regressions=20, full_modes=timing, preview_request=case)
    record['pass'] = True
    (dest/'verification.json').write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('PASS export', target.name, digest(target))


if __name__ == '__main__':
    main()
