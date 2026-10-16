"""Extract actual MAX II EPM1270 POF UFM payload and compare every MIF word.

This is an intentionally narrow parser for Quartus 9.1's uncompressed
EPM1270T144C5 POF record format. It refuses other payload formats rather
than guessing. It never accesses JTAG, Programmer, or a physical device.
"""
import argparse
import hashlib
import json
import re
import struct
import shutil
import subprocess
import tempfile
from pathlib import Path


def digest(data):
    return hashlib.sha256(data).hexdigest()


def extract(pof):
    raw = pof.read_bytes()
    if raw[:8] != b"POF\x00\x00\x00\x01\x00":
        raise ValueError("Unsupported POF signature/version")
    count, = struct.unpack_from("<I", raw, 8)
    offset, records, payloads, device = 12, [], [], None
    for _ in range(count):
        if offset + 6 > len(raw):
            raise ValueError("Truncated POF record header")
        tag, size = struct.unpack_from("<HI", raw, offset)
        start = offset + 6
        end = start + size
        if end > len(raw):
            raise ValueError("Truncated POF record payload")
        data = raw[start:end]
        records.append({"tag": f"0x{tag:02x}", "offset": offset, "size": size})
        if tag == 2:
            device = data.rstrip(b"\x00").decode("ascii")
        if tag == 0x18:
            if size != 1036 or data[:12] != bytes.fromhex("000000000000002000000100"):
                raise ValueError("Unsupported UFM record header/size; refuses inferred decoding")
            payloads.append(data[12:])
        offset = end
    if offset != len(raw) or device != "EPM1270T144C5" or len(payloads) != 1:
        raise ValueError(f"Unsupported POF structure/device/UFM count: {device}, {len(payloads)}")
    payload = payloads[0]
    words = list(struct.unpack("<512H", payload))
    return words, {"pof": str(pof.resolve()), "pof_sha256": digest(raw),
                   "device": device, "records": records,
                   "ufm_payload_bytes": len(payload), "ufm_payload_sha256": digest(payload),
                   "ufm_words": len(words), "ufm_all_erased": all(w == 0xffff for w in words)}


def read_mif(path):
    text = path.read_text(encoding="utf-8-sig")
    text = re.sub(r"%.*?%|--[^\n]*", "", text, flags=re.S)
    params = dict((key.upper(), value.upper()) for key, value in
                  re.findall(r"(WIDTH|DEPTH|ADDRESS_RADIX|DATA_RADIX)\s*=\s*(\w+)\s*;", text, re.I))
    if params.get("WIDTH") != "16" or params.get("DEPTH") != "512":
        raise ValueError("Expected a complete WIDTH=16 DEPTH=512 MIF")
    radix = {"UNS": 10, "DEC": 10, "HEX": 16, "BIN": 2, "OCT": 8}
    address_base = radix[params["ADDRESS_RADIX"]]
    data_base = radix[params["DATA_RADIX"]]
    content = re.search(r"CONTENT\s+BEGIN(.*?)END\s*;", text, re.S | re.I)
    if not content:
        raise ValueError("Missing MIF CONTENT BEGIN/END")
    words = [None] * 512
    for assignment in content[1].split(";"):
        if not assignment.strip():
            continue
        address_text, data_text = assignment.split(":")
        data = int(data_text.strip(), data_base)
        if not 0 <= data <= 65535:
            raise ValueError("MIF word overflow")
        address_text = address_text.strip()
        if address_text.startswith("["):
            low, high = (int(a.strip(), address_base) for a in address_text[1:-1].split(".."))
        else:
            low = high = int(address_text, address_base)
        if not 0 <= low <= high < 512:
            raise ValueError("MIF address range overflow")
        for address in range(low, high + 1):
            if words[address] is not None:
                raise ValueError("MIF duplicate address")
            words[address] = data
    if any(w is None for w in words):
        raise ValueError("MIF leaves unspecified words")
    return words


def official_svf_words(pof, cpf, out):
    # File conversion only: quartus_cpf neither connects to nor programs JTAG.
    # Temporary files are confined to the explicitly named evidence directory.
    with tempfile.TemporaryDirectory(prefix="cpf_extract_", dir=out.resolve()) as temporary:
        root = Path(temporary)
        shutil.copyfile(pof, root / "image.pof")
        command = [str(cpf), "-c", "-q", "4.5MHz", "-g", "3.3", "-n", "p", "image.pof", "image.svf"]
        result = subprocess.run(command, cwd=root, capture_output=True)
        (out / "quartus_cpf.log").write_bytes(result.stdout + result.stderr)
        if result.returncode:
            raise ValueError("Official Quartus POF-to-SVF conversion failed; see quartus_cpf.log")
        raw = (root / "image.svf").read_bytes()
    text = re.sub(r"!.*", "", raw.decode("ascii"))
    # The official MAX II programming algorithm sets ISP address=1 to select
    # UFM, issues ISC_PROGRAM (2F4), then shifts exactly 512 16-bit words.
    blocks = re.findall(r"SIR\s+10\s+TDI\s*\(203\)\s*;\s*RUNTEST[^;]*;\s*"
                        r"SDR\s+15\s+TDI\s*\(0001\)\s*;\s*"
                        r"SIR\s+10\s+TDI\s*\(2F4\)\s*;(.*?)(?=SIR\s+10|\Z)",
                        text, re.S | re.I)
    if len(blocks) != 1:
        raise ValueError(f"Expected one official SVF UFM programming block, got {len(blocks)}")
    serial_words = re.findall(r"SDR\s+16\s+TDI\s*\(([0-9A-F]{4})\)\s*;", blocks[0], re.I)
    if len(serial_words) != 512:
        raise ValueError(f"Official SVF UFM program block contains {len(serial_words)} words, expected 512")
    # SVF TDI integers represent the JTAG serial bit ordering; reverse 16 bits
    # to recover the logical ALTUFM word. Cross-checked against known P2 MIF.
    words = [int(f"{int(w, 16):016b}"[::-1], 2) for w in serial_words]
    (out / "official_ufm_program.svf").write_text(blocks[0], encoding="ascii")
    (out / "official_ufm.mem").write_text("".join(f"{w:04x}\n" for w in words), encoding="ascii")
    return words, {"converter": str(cpf), "conversion": "quartus_cpf -c -q 4.5MHz -g 3.3 -n p image.pof image.svf",
                   "full_svf_sha256": digest(raw), "ufm_program_word_count": 512,
                   "ufm_select_address": "0001", "isc_program_instruction": "2F4"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pof", type=Path)
    parser.add_argument("mif", type=Path)
    parser.add_argument("--baseline-pof", type=Path)
    parser.add_argument("--quartus-cpf", type=Path,
                        default=Path("E:/quartus/QuartusII91/quartus/bin64/quartus_cpf.exe"))
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    words, report = extract(args.pof)
    official_words, official = official_svf_words(args.pof, args.quartus_cpf, args.out)
    if official_words != words:
        raise ValueError("POF tag0x18 decoding disagrees with official Quartus UFM program data")
    official["all_words_match_direct_pof_payload"] = True
    report["official_svf_crosscheck"] = official
    expected = read_mif(args.mif)
    mismatch = [{"address": i, "pof": f"{a:04x}", "mif": f"{b:04x}"}
                for i, (a, b) in enumerate(zip(words, expected)) if a != b]
    report.update({"mif": str(args.mif.resolve()), "mif_sha256": digest(args.mif.read_bytes()),
                   "compared_words": 512, "mismatch_count": len(mismatch),
                   "first_mismatches": mismatch[:16]})
    if args.baseline_pof:
        baseline_words, baseline = extract(args.baseline_pof)
        baseline["words_different_from_candidate"] = sum(a != b for a, b in zip(words, baseline_words))
        baseline["words_different_from_expected"] = sum(a != b for a, b in zip(expected, baseline_words))
        report["baseline"] = baseline
    report["pass"] = not mismatch
    (args.out / "pof_ufm.mem").write_text("".join(f"{w:04x}\n" for w in words), encoding="ascii")
    (args.out / "pof_ufm.bin").write_bytes(struct.pack("<512H", *words))
    (args.out / "verification.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{'PASS' if not mismatch else 'FAIL'} actual POF UFM: 512 words compared, mismatches={len(mismatch)}, erased={report['ufm_all_erased']}")
    if mismatch:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
