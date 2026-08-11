#!/usr/bin/env python3
"""Validation for the Python PE analyzer used alongside the mcode scanner."""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

import ahk_inspect  # noqa: E402


KNOWN_V2_X64_EXES = [
    Path(r"D:\Tech\Projects\Autohotkey\Lib\.worktrees\ahk-runtime\AutoHotkey64.exe"),
    Path(r"D:\Tech\Projects\Autohotkey\Lib\.codex\autohotkey-2.0.26\runtime\AutoHotkey64.exe"),
    Path(r"D:\Tech\Projects\Autohotkey\v2.0.0\AutoHotkey64.exe"),
    Path(r"D:\Tech\Projects\Autohotkey\v2.0-beta.10\AutoHotkey64.exe"),
]


class AhkInspectTest(unittest.TestCase):
    def test_mcode_blob_is_embedded(self):
        text = (ROOT / "lib" / "ahk_hack.ahk").read_text(encoding="utf-8")
        marker = 'MC_BIF_SCANNER_X64 := "'
        start = text.index(marker) + len(marker)
        end = text.index('"', start)
        blob = text[start:end]
        self.assertGreater(len(blob), 1000)
        self.assertTrue(all(c in "0123456789abcdefABCDEF" for c in blob))

    def test_known_v2_exes_parse_consistently(self):
        exes = [p for p in KNOWN_V2_X64_EXES if p.exists()]
        self.assertGreaterEqual(len(exes), 2)
        for path in exes:
            with self.subTest(exe=path.name):
                report = ahk_inspect.analyze_exe(path)
                self.assertEqual(report["detected_family"], "v2")
                self.assertTrue(report["pe"]["is64"])
                for key in ("builtins", "native_functions", "builtin_vars"):
                    table = report[key]
                    self.assertTrue(table["found"], "%s missing in %s" % (key, path.name))
                    self.assertGreater(table["count"], 50)
                    self.assertTrue(table["sorted"])
                    entries = table["entries"]
                    names = [e["name"] for e in entries]
                    self.assertEqual(names, sorted(names, key=str.lower))
                    self.assertEqual(len(names), table["count"])
                # JSON round-trip
                text = json.dumps(report, ensure_ascii=False)
                self.assertIn(report["version"].get("FileVersion", ""), text)


if __name__ == "__main__":
    unittest.main()
