#!/usr/bin/env python3
"""Generate the root blog files from the templates in tools/.

The blog no longer embeds the single-file core: the article plus the full
source exceeds forum post length limits, so the appendix links to the
repository raw file and the Pages appendix instead.  This script is kept
as the single entry point that publishes the templates to the repo root.
"""

from __future__ import annotations

import pathlib


ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATES = {
    "en": ROOT / "tools" / "blog_ahk_hack_en.txt",
    "zh": ROOT / "tools" / "blog_ahk_hack_zh.txt",
}
OUTPUTS = {
    "en": ROOT / "blog_ahk_hack_en.txt",
    "zh": ROOT / "blog_ahk_hack.txt",
}


def build() -> None:
    for lang, template in TEMPLATES.items():
        text = template.read_text(encoding="utf-8")
        OUTPUTS[lang].write_text(text, encoding="utf-8")
        print(f"wrote {OUTPUTS[lang]}")


if __name__ == "__main__":
    build()
