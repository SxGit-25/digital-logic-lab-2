"""Compare actual JTAG Examine data with the programmed CFM and UFM records."""
from pathlib import Path
import hashlib,json,struct,sys
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[3]
source=ROOT/'radar/p5a/restart/pofs/step3_A0_pending_snapshot_syncSW7_UFM_alarmInverse_1253LE.pof'
readback=HERE/'readback.pof'
def records(path):
    raw=path.read_bytes()
    assert raw[:8]==b'POF\x00\x00\x00\x01\x00'
    count=struct.unpack_from('<I',raw,8)[0]
    offset=12;result={}
    for _ in range(count):
        tag,size=struct.unpack_from('<HI',raw,offset)
        assert tag not in result
        result[tag]=raw[offset+6:offset+6+size]
        assert len(result[tag])==size
        offset+=6+size
    assert offset==len(raw)
    return result
expected=records(source);actual=records(readback)
assert expected[2].rstrip(b'\x00')==b'EPM1270T144C5'
assert actual[2].rstrip(b'\x00')==b'EPM1270'
assert len(expected[0x11])==26124 and len(expected[0x18])==1036
assert actual[0x11]==expected[0x11], 'CFM readback mismatch'
assert actual[0x18]==expected[0x18], 'UFM readback mismatch'
sys.path.insert(0,str(ROOT/'radar/p5a/ufm'))
from check_pof_ufm import read_mif
words=list(struct.unpack('<512H',actual[0x18][12:]))
assert words==read_mif(ROOT/'radar/unified_scan/background.mif'), 'Board UFM differs from background MIF'
assert any(v!=0xffff for v in words)
for name in ('program_verify.log','examine.log'):
    log=(HERE/name).read_text(errors='replace')
    assert 'Successfully performed operation(s)' in log and '0 errors, 0 warnings' in log
report=dict(result='PASS',program_verify='PASS',jtag_examine='PASS',device='EPM1270',jtag_id='0x020A30DD',
            source_pof=str(source),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
            readback_sha256=hashlib.sha256(readback.read_bytes()).hexdigest(),
            cfm_record_byte_identical=True,cfm_data_bytes=26112,
            ufm_record_byte_identical=True,ufm_data_bytes=1024,ufm_words_equal_mif=512,
            physical_display_acceptance='not yet confirmed')
(HERE/'readback_verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(HERE/'烧录结果.md').write_text('''# 烧录结果

2026-10-16 19:15:43–19:16:16（Asia/Shanghai）。USB-Blaster [USB-0]，EPM1270，JTAG ID 0x020A30DD。

烧录最终保留第1a/1b、2、3项的单一POF：1253LE，setup 3.361ns，hold 1.078ns。第4–7项已回退，未写入超限候选。

- 整文件Program + Verify成功，0错误、0警告。
- JTAG Examine回读成功，0错误、0警告。
- CFM记录与最终POF逐字节一致（有效数据26112字节）。
- UFM记录与最终POF逐字节一致（1024字节/512字），并与背景MIF全部512字一致。
- POF的器件型号元数据在回读文件中简写为EPM1270；配置/背景记录独立比较通过。

证据：program_verify.log、examine.log、readback.pof、readback_verification.json。脚本verify_readback.py可复核。

实物画面尚待用户确认：圈完整、目标单点、无竖条、无错位；报警反显解除后恢复正常。此前一页总结中的“尚未烧录”描述的是编译交付时的历史状态，本记录更新为已烧录并校验。
''',encoding='utf-8')
print('PASS physical readback: CFM identical; all 512 UFM words identical to final POF and background MIF')
