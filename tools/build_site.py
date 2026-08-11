#!/usr/bin/env python3
"""Build docs/ from bilingual HTML templates and embed the single-file core."""

from __future__ import annotations

import html
import pathlib
import shutil


ROOT = pathlib.Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "tools" / "site_templates"
DOCS = ROOT / "docs"
SINGLE = ROOT / "ahk_hack_single.ahk"
MARKER = "<!--AHK_SINGLE_FILE-->"


def build(lang: str, output: str) -> None:
    template = (TEMPLATES / f"index.{lang}.html").read_text(encoding="utf-8")
    source = html.escape(SINGLE.read_text(encoding="utf-8"))
    if MARKER not in template:
        raise RuntimeError(f"{template}: missing {MARKER}")
    with (DOCS / output).open("w", encoding="utf-8", newline="\n") as fh:
        fh.write(template.replace(MARKER, source))
    print(f"wrote {DOCS / output}")


def main() -> None:
    DOCS.mkdir(exist_ok=True)
    shutil.copy2(TEMPLATES / "style.css", DOCS / "style.css")
    shutil.copy2(TEMPLATES / "app.js", DOCS / "app.js")
    build("en", "index.html")
    build("zh", "index.zh.html")
    print("site ready in docs/")


if __name__ == "__main__":
    main()
