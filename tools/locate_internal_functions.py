#!/usr/bin/env python3
"""Locate internal AutoHotkey expression functions in a given exe.

AutoHotkey does not export its expression compiler, so this tool finds the
functions by fingerprint:

  1. Locate unique UTF-16 error strings in .rdata (for example
     "Missing operand." used by Line::ExpressionToPostfix and
     "Error evaluating expression." used by Line::ExpandExpression).
  2. Scan .text for RIP-relative LEA instructions that reference those
     strings.
  3. Walk backwards from each reference to the previous int3 padding to find
     the function entry point.

The reported RVAs are relative to the module image base and can be consumed
by an mcode harness that constructs a Line/ArgStruct and calls the parser and
evaluator directly.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

import pefile


FINGERPRINTS = {
    "expand_expression": "Error evaluating expression.",
    "expression_to_postfix": "Missing operand.",
}


def _sections(pe):
    out = []
    for sec in pe.sections:
        name = sec.Name.decode("latin1").rstrip("\x00")
        out.append(
            {
                "name": name,
                "rva": sec.VirtualAddress,
                "size": sec.Misc_VirtualSize or len(sec.get_data()),
                "data": sec.get_data(),
            }
        )
    return out


def _find_utf16(secs, text, max_hits=8):
    needle = text.encode("utf-16-le") + b"\x00\x00"
    hits = []
    for sec in secs:
        if sec["name"] not in (".rdata", ".data"):
            continue
        data = sec["data"]
        pos = data.find(needle)
        while pos >= 0 and len(hits) < max_hits:
            hits.append(sec["rva"] + pos)
            pos = data.find(needle, pos + 2)
    return hits


def _find_rip_refs(text_sec, target_rva):
    data = text_sec["data"]
    base = text_sec["rva"]
    refs = []
    for i in range(len(data) - 7):
        if data[i] not in (0x48, 0x4C):
            continue
        if data[i + 1] != 0x8D:
            continue
        if data[i + 2] not in (0x05, 0x0D, 0x15, 0x1D, 0x25, 0x2D, 0x35, 0x3D):
            continue
        disp = struct.unpack_from("<i", data, i + 3)[0]
        next_ip = base + i + 7
        if next_ip + disp == target_rva:
            refs.append(base + i)
    return refs


def _function_start(text_sec, ref_rva):
    data = text_sec["data"]
    base = text_sec["rva"]
    off = ref_rva - base
    i = off
    while i > 0:
        if data[i - 1] == 0xCC and i >= 2 and data[i - 2] == 0xCC:
            break
        i -= 1
    return base + i


def locate(path):
    pe = pefile.PE(str(path))
    secs = _sections(pe)
    text = next(s for s in secs if s["name"] == ".text")
    result = {"file": str(Path(path).resolve()), "functions": {}}
    for key, fingerprint in FINGERPRINTS.items():
        strings = _find_utf16(secs, fingerprint)
        refs = []
        for str_rva in strings:
            refs.extend(_find_rip_refs(text, str_rva))
        starts = {}
        for ref in refs:
            start = _function_start(text, ref)
            starts.setdefault(start, []).append(ref)
        if not starts:
            result["functions"][key] = {"found": False}
            continue
        best_start = max(starts, key=lambda s: len(starts[s]))
        result["functions"][key] = {
            "found": True,
            "rva": best_start,
            "va": pe.OPTIONAL_HEADER.ImageBase + best_start,
            "string_refs": len(refs),
            "refs": [hex(r) for r in starts[best_start]],
        }
    return result


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("exe", help="path to an AutoHotkey executable")
    parser.add_argument("-o", "--out", help="JSON output path")
    args = parser.parse_args(argv)
    report = locate(args.exe)
    text = json.dumps(report, indent=2)
    if args.out:
        Path(args.out).write_text(text, encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
