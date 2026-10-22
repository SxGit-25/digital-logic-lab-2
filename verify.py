"""Verify the frozen delivery, historical readback, and optional clean build."""
from pathlib import Path
import hashlib, json, re, struct

ROOT = Path(__file__).resolve().parent
EXPECTED = '45963657dbc6975a83e8de8b566d6ee072bb1a34025de2c2e890bc1647ee71f3'

def records(path):
    raw = path.read_bytes()
    assert raw[:8] == b'POF\x00\x00\x00\x01\x00', path
    offset, result = 12, {}
    for _ in range(struct.unpack_from('<I', raw, 8)[0]):
        tag, size = struct.unpack_from('<HI', raw, offset)
        assert tag not in result
        result[tag] = raw[offset+6:offset+6+size]
        assert len(result[tag]) == size
        offset += 6 + size
    assert offset == len(raw)
    return result

def main():
    frozen = ROOT / 'delivery/radar_1270LE.pof'
    assert hashlib.sha256(frozen.read_bytes()).hexdigest() == EXPECTED
    reference = records(frozen)
    readback = records(ROOT / 'verification/programming/readback.pof')
    assert reference[0x11] == readback[0x11], 'Historical CFM mismatch'
    assert reference[0x18] == readback[0x18], 'Historical UFM mismatch'
    mif = (ROOT / 'quartus/background.mif').read_text()
    words = {int(a, 16): int(v, 16) for a, v in re.findall(r'([0-9a-fA-F]+)\s*:\s*([0-9a-fA-F]+)\s*;', mif)}
    assert len(words) == 512
    assert [words[i] for i in range(512)] == list(struct.unpack('<512H', reference[0x18][12:]))
    manifest = json.loads((ROOT / 'verification/source_manifest.json').read_text(encoding='utf-8'))
    for entry in manifest:
        path = ROOT / entry['path']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
    qsf = ROOT / 'quartus/radar_unified_bcd.qsf'
    for path in re.findall(r'-name (?:VERILOG_FILE|SDC_FILE|MIF_FILE)\s+(\S+)', qsf.read_text()):
        assert (qsf.parent / path).is_file(), path
    result = dict(delivery_sha256=EXPECTED, historical_cfm_match=True, historical_ufm_match=True, background_words=512, source_manifest_files=len(manifest))
    build = ROOT / 'build'
    if build.exists():
        fit = (build / 'radar_unified_bcd.fit.summary').read_text()
        sta = (build / 'radar_unified_bcd.sta.summary').read_text()
        assert 'Fitter Status : Successful' in fit
        assert re.search(r'Total logic elements\s*:\s*1,270\s*/\s*1,270', fit), fit
        setup = float(re.search(r"Type\s*:\s*Setup 'clk'\s+Slack\s*:\s*([-\d.]+)", sta)[1])
        hold = float(re.search(r"Type\s*:\s*Hold 'clk'\s+Slack\s*:\s*([-\d.]+)", sta)[1])
        assert setup >= 1 and hold >= 0
        actual = records(build / 'radar_unified_bcd.pof')
        assert actual[0x11] == reference[0x11], 'Rebuilt CFM differs from frozen delivery'
        assert actual[0x18] == reference[0x18], 'Rebuilt UFM differs from frozen delivery'
        result['clean_build'] = dict(le=1270, setup_ns=setup, hold_ns=hold, cfm_record_identical=True, ufm_record_identical=True)
        (build / 'verification.json').write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))

if __name__ == '__main__':
    main()
