#!/usr/bin/env python3
"""Compile mcode/scanner.c and embed the resulting x64 machine code."""

from __future__ import annotations

import argparse
import pathlib
import struct
import subprocess
import sys
import tempfile


ROOT = pathlib.Path(__file__).resolve().parent.parent
CLANG = pathlib.Path(r"F:\Tech\LLVM\bin\clang.exe")
SCANNER_C = ROOT / "lib" / "mcode" / "scanner.c"
EXPORT_SCANNER_C = ROOT / "lib" / "mcode" / "export_scanner.c"
INPROC_EVAL_C = ROOT / "lib" / "mcode" / "inproc_eval.c"
INTERNAL_LOCATOR_C = ROOT / "lib" / "mcode" / "internal_locator.c"
MEM_SCRIPT_C = ROOT / "lib" / "mcode" / "mem_script.c"
REMOTE_EVAL_STUB_C = ROOT / "lib" / "mcode" / "remote_eval_stub.c"
REMOTE_CALL_STUB_C = ROOT / "lib" / "mcode" / "remote_call_stub.c"
AHK_OUT = ROOT / "ahk_hack_single.ahk"


def parse_coff_text(obj: bytes):
    machine, num_sections = struct.unpack_from("<HH", obj, 0)
    if machine != 0x8664:
        raise RuntimeError("expected x64 COFF object, machine=0x%X" % machine)
    opt_size = struct.unpack_from("<H", obj, 16)[0]
    section_table = 20 + opt_size
    sections = []
    for i in range(num_sections):
        hdr = section_table + i * 40
        name_raw = obj[hdr : hdr + 8].rstrip(b"\x00")
        vsize, va, raw_size, raw_ptr = struct.unpack_from("<IIII", obj, hdr + 8)
        reloc_ptr, lineno_ptr = struct.unpack_from("<II", obj, hdr + 24)
        nreloc, nlineno = struct.unpack_from("<HH", obj, hdr + 32)
        sections.append(
            {
                "name": name_raw,
                "raw_size": raw_size,
                "raw_ptr": raw_ptr,
                "reloc_ptr": reloc_ptr,
                "nreloc": nreloc,
            }
        )
    text_sections = [s for s in sections if s["name"] == b".text"]
    if len(text_sections) != 1:
        raise RuntimeError(
            "expected exactly one .text section, found %d" % len(text_sections)
        )
    text_sec = text_sections[0]
    if text_sec["raw_ptr"] + text_sec["raw_size"] > len(obj):
        raise RuntimeError(
            ".text section truncated: raw_ptr=%d raw_size=%d file=%d"
            % (text_sec["raw_ptr"], text_sec["raw_size"], len(obj))
        )
    text = bytearray(obj[text_sec["raw_ptr"] : text_sec["raw_ptr"] + text_sec["raw_size"]])
    if not text:
        raise RuntimeError("empty .text section")

    # Resolve intra-object REL32 references so the blob is self-contained.
    symbol_table = struct.unpack_from("<I", obj, 8)[0]
    symbol_count = struct.unpack_from("<I", obj, 12)[0]
    for j in range(text_sec["nreloc"]):
        reloc_off = text_sec["reloc_ptr"] + j * 10
        field_off, symbol_index, reloc_type = struct.unpack_from("<IIH", obj, reloc_off)
        if reloc_type != 4:  # IMAGE_REL_AMD64_REL32
            raise RuntimeError(
                "unhandled relocation type %d in .text" % reloc_type
            )
        if symbol_index >= symbol_count:
            raise RuntimeError("relocation symbol index out of range")
        sym = symbol_table + symbol_index * 18
        value, section_number = struct.unpack_from("<IH", obj, sym + 8)
        if section_number < 1 or section_number > num_sections:
            raise RuntimeError("relocation targets absolute data; not self-contained")
        target_sec = sections[section_number - 1]
        if target_sec["name"] != b".text":
            raise RuntimeError("relocation escapes .text; not self-contained")
        target_off = value
        if field_off + 4 > len(text):
            raise RuntimeError(
                "relocation field offset %d past end of .text" % field_off
            )
        if target_off >= len(text):
            raise RuntimeError(
                "relocation target 0x%X escapes the blob (size 0x%X)"
                % (target_off, len(text))
            )
        field_abs = field_off
        displacement = target_off - (field_abs + 4)
        struct.pack_into("<i", text, field_off, displacement)
    return bytes(text)


def build_blob(src: pathlib.Path) -> bytes:
    if not CLANG.exists():
        raise RuntimeError("clang not found at %s" % CLANG)
    with tempfile.TemporaryDirectory() as tmp:
        obj_path = pathlib.Path(tmp) / "scanner.obj"
        cmd = [
            str(CLANG),
            "-c",
            "-O2",
            "-target",
            "x86_64-pc-windows-msvc",
            "-ffreestanding",
            "-fno-builtin",
            "-fno-stack-protector",
            "-fno-unwind-tables",
            "-fno-asynchronous-unwind-tables",
            "-fno-jump-tables",
            "-o",
            str(obj_path),
            str(src),
        ]
        subprocess.run(cmd, check=True, capture_output=True)
        return parse_coff_text(obj_path.read_bytes())


def ahk_hex(data: bytes) -> str:
    return data.hex()


def replace_marker(text: str, marker: str, blob: bytes) -> str:
    start = text.index(marker) + len(marker)
    end = text.index('"', start)
    return text[:start] + ahk_hex(blob) + text[end:]


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=pathlib.Path, default=AHK_OUT)
    parser.add_argument(
        "--embed-only",
        action="store_true",
        help="only regenerate the machine-code constant in ahk_mcode.ahk",
    )
    args = parser.parse_args(argv)
    code = build_blob(SCANNER_C)
    export_code = build_blob(EXPORT_SCANNER_C)
    eval_code = build_blob(INPROC_EVAL_C)
    locator_code = build_blob(INTERNAL_LOCATOR_C)
    mem_script_code = build_blob(MEM_SCRIPT_C)
    remote_eval_stub_code = build_blob(REMOTE_EVAL_STUB_C)
    remote_call_stub_code = build_blob(REMOTE_CALL_STUB_C)
    if args.embed_only:
        text = args.out.read_text(encoding="utf-8")
        text = replace_marker(text, 'MC_BIF_SCANNER_X64 := "', code)
        text = replace_marker(text, 'MC_PE_EXPORT_SCANNER_X64 := "', export_code)
        text = replace_marker(text, 'MC_INPROC_EVAL_X64 := "', eval_code)
        text = replace_marker(text, 'MC_INTERNAL_LOCATOR_X64 := "', locator_code)
        text = replace_marker(text, 'MC_MEM_SCRIPT_X64 := "', mem_script_code)
        text = replace_marker(text, 'MC_REMOTE_EVAL_STUB_X64 := "', remote_eval_stub_code)
        text = replace_marker(text, 'MC_REMOTE_CALL_STUB_X64 := "', remote_call_stub_code)
        args.out.write_text(text, encoding="utf-8")
    else:
        # The placeholder file is generated once by ahk_mcode.ahk's author;
        # this branch is mainly useful for CI/verification.
        raise RuntimeError(
            "use --embed-only; the AHK file itself is the checked-in artifact"
        )
    print("bif scanner size: %d bytes" % len(code))
    print("export scanner size: %d bytes" % len(export_code))
    print("inproc eval size: %d bytes" % len(eval_code))
    print("internal locator size: %d bytes" % len(locator_code))
    print("mem script loader size: %d bytes" % len(mem_script_code))
    print("remote eval stub size: %d bytes" % len(remote_eval_stub_code))
    print("remote call stub size: %d bytes" % len(remote_call_stub_code))
    print("embedded into: %s" % args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
