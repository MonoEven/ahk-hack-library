#!/usr/bin/env python3
"""Build root blog files by embedding the single-file core."""

from __future__ import annotations

import pathlib


ROOT = pathlib.Path(__file__).resolve().parent.parent
SINGLE = ROOT / "ahk_hack_single.ahk"
TEMPLATES = {
    "en": ROOT / "tools" / "blog_ahk_hack_en.txt",
    "zh": ROOT / "tools" / "blog_ahk_hack_zh.txt",
}
OUTPUTS = {
    "en": ROOT / "blog_ahk_hack_en.txt",
    "zh": ROOT / "blog_ahk_hack.txt",
}
MARKER = "<!--AHK_SINGLE_FILE-->"


def build() -> None:
    source = SINGLE.read_text(encoding="utf-8")
    for lang, template in TEMPLATES.items():
        text = template.read_text(encoding="utf-8")
        if MARKER not in text:
            raise RuntimeError(f"{template}: missing {MARKER}")
        OUTPUTS[lang].write_text(text.replace(MARKER, source), encoding="utf-8")
        print(f"wrote {OUTPUTS[lang]}")


if __name__ == "__main__":
    build()
