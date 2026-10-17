"""Verify physical CFM/UFM readback against the frozen beam-min delivery POF."""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT/'radar/beam_min/delivery/beam_min_full_r6-48_XOR_UFM8_keepInverse_1270LE.pof'
EXPECTED_SHA256 = '45963657dbc6975a83e8de8b566d6ee072bb1a34025de2c2e890bc1647ee71f3'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_text(path):
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')


def records(path):
    raw = path.read_bytes()
    assert raw[:8] == b'POF\x00\x00\x00\x01\x00'
    count = struct.unpack_from('<I', raw, 8)[0]
    offset = 12
    result = {}
    for _ in range(count):
        tag, size = struct.unpack_from('<HI', raw, offset)
        assert tag not in result
        result[tag] = raw[offset+6:offset+6+size]
        assert len(result[tag]) == size
        offset += 6+size
    assert offset == len(raw)
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('evidence', type=Path)
    folder = parser.parse_args().evidence.resolve()
    assert sha(SOURCE) == EXPECTED_SHA256
    op = json.loads(read_text(folder/'operation.json'))
    assert op['SHA256'].lower() == EXPECTED_SHA256
    readback = folder/'readback.pof'
    expected, actual = records(SOURCE), records(readback)
    assert expected[2].rstrip(b'\0') == b'EPM1270T144C5'
    assert actual[2].rstrip(b'\0') == b'EPM1270'
    assert len(expected[0x11]) == 26124 and len(expected[0x18]) == 1036
    assert actual[0x11] == expected[0x11], 'CFM readback mismatch'
    assert actual[0x18] == expected[0x18], 'UFM readback mismatch'
    sys.path.insert(0, str(ROOT/'radar/p5a/ufm'))
    from check_pof_ufm import read_mif
    words = list(struct.unpack('<512H', actual[0x18][12:]))
    mif = ROOT/'radar/unified_scan/results/beam_min_byte_a/bcd/source/lcd_p4/background.mif'
    assert words == read_mif(mif), 'Board UFM differs from same-build background MIF'
    assert any(v != 0xffff for v in words)
    for name in ['program_verify.log', 'examine.log']:
        log = read_text(folder/name)
        assert 'Successfully performed operation(s)' in log
        assert '0 errors, 0 warnings' in log
        assert '0x020A30DD' in log
    frozen = ROOT/'radar/p5a/restart/pofs/step3_A0_pending_snapshot_syncSW7_UFM_alarmInverse_1253LE.pof'
    assert sha(frozen) == '67332205e468962a8a7a9a475d2eab27594de9549e2a1dde77653211edc4f50a'
    report = dict(result='PASS', time=op['Time'], cable=op['Cable'], device='EPM1270', jtag_id='0x020A30DD',
                  source_pof=str(SOURCE.relative_to(ROOT)), source_sha256=sha(SOURCE),
                  readback_sha256=sha(readback), program_verify='PASS', jtag_examine='PASS',
                  cfm_record_byte_identical=True, cfm_data_bytes=26112,
                  ufm_record_byte_identical=True, ufm_data_bytes=1024, ufm_words_equal_mif=512,
                  frozen_1253_pof_unchanged=True, physical_display_acceptance='not yet confirmed')
    (folder/'readback_verification.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (folder/'烧录结果.md').write_text(f'''# beam-min-1270 烧录结果

{op['Time']}（Asia/Shanghai），USB-Blaster [USB-0]，EPM1270，JTAG ID 0x020A30DD。

已烧录固定 r6–48 XOR 扫描线＋8位UFM读取版本，报警反显保留。1270LE，setup 2.994ns，hold 1.078ns；构建标签 `beam-min-1270`。

- 完整POF Program + Verify成功，0错误、0警告。
- JTAG Examine回读成功，0错误、0警告。
- CFM记录与交付POF逐字节一致（有效数据26112字节）。
- UFM记录与交付POF逐字节一致（1024字节），512word全部与同次编译MIF一致。
- 原delivery-1253回退POF哈希保持不变。
- 新POF SHA256：`{sha(SOURCE)}`。

证据：`program_verify.log`、`examine.log`、`readback.pof`、`readback_verification.json`。复核：`python radar/beam_min/programming/verify_readback.py radar/beam_min/programming/{folder.name}`。

构建交付报告中的“尚未烧录”是编译交付时的历史状态；本记录更新为已写入并回读核对。实物画面仍待验收：两种模式扫描线正常且撤线无残留、圈完整、目标单点、无竖条或错位，报警解除后恢复正常显示。
''', encoding='utf-8')
    print('PASS physical readback: CFM identical; UFM 512 words identical to delivery POF and same-build MIF')


if __name__ == '__main__':
    main()
