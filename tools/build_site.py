#!/usr/bin/env python3
"""Build docs/ from the root BBCode blog sources and embed the single-file core."""

from __future__ import annotations

import html
import pathlib
import re
import shutil


ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
TEMPLATES = ROOT / "tools" / "site_templates"
SINGLE = ROOT / "ahk_hack_single.ahk"
MARKER = "<!--AHK_SINGLE_FILE-->"

EN = ROOT / "docs" / "pages_en.txt"
ZH = ROOT / "docs" / "pages_zh.txt"


def inline(text: str) -> str:
    text = re.sub(r"\[c\](.*?)\[/c\]", r"<code>\1</code>", text, flags=re.S)
    text = re.sub(r"\[b\](.*?)\[/b\]", r"<strong>\1</strong>", text, flags=re.S)
    text = re.sub(
        r"\[url=([^\]]+)\](.*?)\[/url\]",
        r'<a href="\1">\2</a>',
        text,
        flags=re.S,
    )
    text = re.sub(r"\[color=#[0-9A-Fa-f]{6}\](.*?)\[/color\]", r"\1", text, flags=re.S)
    return text


def plain(text: str) -> str:
    text = re.sub(r"\[/?[a-z]+(?:=[^\]]+)?\]", "", text)
    return html.escape(text).replace("&quot;", '"')


def parse(source: str):
    body: list[str] = []
    toc: list[tuple[str, str]] = []
    lines = source.splitlines()
    para: list[str] = []
    list_open = False
    section_open = False
    section = 0
    i = 0

    def flush_para() -> None:
        nonlocal para
        if para:
            body.append("<p>" + inline(" ".join(para)) + "</p>")
            para = []

    def close_list() -> None:
        nonlocal list_open
        if list_open:
            body.append("</ul>")
            list_open = False

    while i < len(lines):
        line = lines[i].rstrip()
        if not line:
            flush_para()
            close_list()
            i += 1
            continue

        code = re.match(r"\[codebox=([^\s\]]+)(?:\s+file=([^\]]+))?\]", line)
        if code:
            flush_para()
            close_list()
            lang = code.group(1)
            block: list[str] = []
            i += 1
            while i < len(lines) and lines[i].strip() != "[/codebox]":
                block.append(lines[i])
                i += 1
            i += 1
            code_html = html.escape("\n".join(block))
            body.append(
                f'<pre class="lang-{html.escape(lang)}"><code>{code_html}</code></pre>'
            )
            continue

        color_heading = re.match(r"\[color=#[0-9A-Fa-f]{6}\]\[b\](.*?)\[/b\]\[/color\]", line)
        if color_heading:
            flush_para()
            close_list()
            body.append("<h3>" + inline(color_heading.group(1)) + "</h3>")
            i += 1
            continue

        heading = re.match(r"\[b\]\s*(\d+)\.\s+(.*?)\s*\[/b\]", line)
        if heading:
            flush_para()
            close_list()
            if section_open:
                body.append("</section>")
            section += 1
            ident = f"sec-{section}"
            title = plain(heading.group(2))
            body.append(f'<section id="{ident}"><h2>{title}</h2>')
            section_open = True
            toc.append((ident, title))
            i += 1
            continue

        if line.startswith("|"):
            flush_para()
            close_list()
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i].strip())
                i += 1
            if len(rows) >= 2 and re.match(r"^\|[\s:\-|]+\|$", rows[1]):
                header = [inline(c.strip()) for c in rows[0].strip("|").split("|")]
                body_rows = rows[2:]
                table = ["<table><thead><tr>"]
                table.extend(f"<th>{c}</th>" for c in header)
                table.append("</tr></thead><tbody>")
                for row in body_rows:
                    cells = [inline(c.strip()) for c in row.strip("|").split("|")]
                    table.append("<tr>")
                    table.extend(f"<td>{c}</td>" for c in cells)
                    table.append("</tr>")
                table.append("</tbody></table>")
                body.append("".join(table))
            else:
                for row in rows:
                    cells = [inline(c.strip()) for c in row.strip("|").split("|")]
                    body.append("<table><tr>"
                        + "".join(f"<td>{c}</td>" for c in cells)
                        + "</tr></table>")
            continue

        if line.startswith("- "):
            flush_para()
            if not list_open:
                body.append("<ul>")
                list_open = True
            body.append("<li>" + inline(line[2:]) + "</li>")
            i += 1
            continue

        if list_open:
            close_list()
        para.append(line)
        i += 1

    flush_para()
    close_list()
    if section_open:
        body.append("</section>")
    return "\n".join(body), toc


def page(lang: str, title: str, lede: str, body: str, toc: list[tuple[str, str]]) -> str:
    if lang == "zh":
        brand = "ahk-hack"
        brand_sub = "AutoHotkey v2 运行时内省笔记"
        contents = "目录"
        footer = "ahk-hack · AutoHotkey v2 运行时结构扫描库 · MIT License"
        appendix = "附录：单文件核心源码"
        appendix_note = "以下副本由构建脚本根据仓库内文件生成。"
        lang_en = "EN"
        lang_zh = "中文"
        hero_kicker = "技术笔记 · 2026-08-13"
        hero_title = "AutoHotkey64.exe 内部：运行时扫描、进程内 Eval 与远程内省"
        hero_lede = lede
        meta_label = "仓库："
        link_core = "单文件核心"
        link_mcode = "机器码源码"
        link_ahklive = "AhkLive"
        link_tests = "测试"
    else:
        brand = "ahk-hack"
        brand_sub = "runtime introspection notes for AutoHotkey v2"
        contents = "Contents"
        footer = "ahk-hack · AutoHotkey v2 runtime introspection · MIT License"
        appendix = "Appendix: single-file core"
        appendix_note = "The copy below is generated from the repository file by the build script."
        lang_en = "EN"
        lang_zh = "中文"
        hero_kicker = "Field notes · 2026-08-13"
        hero_title = "Inside AutoHotkey64.exe: Runtime Scanning, In-Process Eval, and Remote Introspection"
        hero_lede = lede
        meta_label = "Repository: "
        link_core = "Single-file core"
        link_mcode = "Machine-code sources"
        link_ahklive = "AhkLive"
        link_tests = "Tests"

    toc_html = "\n".join(
        f'<li><a href="#{ident}">{html.escape(text)}</a></li>' for ident, text in toc
    )
    toc_html += f'<li><a href="#appendix">{appendix}</a></li>'

    return f"""<!DOCTYPE html>
<html lang="{lang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{title}</title>
  <meta name="description" content="{html.escape(lede[:160])}">
  <link rel="stylesheet" href="style.css?v=5">
</head>
<body>
  <div class="progress" aria-hidden="true"></div>
  <header class="site-header">
    <div class="wrap">
      <div class="brand">
        <strong>{brand}</strong>
        <span>{brand_sub}</span>
      </div>
      <nav class="lang-switch" aria-label="Language">
        <a class="active" href="index.html" lang="en">{lang_en}</a>
        <a href="index.zh.html" lang="zh">{lang_zh}</a>
      </nav>
    </div>
  </header>

  <main class="layout wrap">
    <aside class="sidebar" id="sidebar">
      <div class="sidebar-head">
        <span>{contents}</span>
        <button type="button" id="sidebarClose" aria-label="Close sidebar">&times;</button>
      </div>
      <nav id="toc" aria-label="Table of contents">
        <ol>
{toc_html}
        </ol>
      </nav>
    </aside>
    <div class="content">
    <section class="hero">
      <div class="kicker">{hero_kicker}</div>
      <h1>{hero_title}</h1>
      <p class="lede">{hero_lede}</p>
      <p class="meta">{meta_label}<a href="https://github.com/MonoEven/ahk-hack-library">MonoEven/ahk-hack-library</a></p>
      <div class="links">
        <a href="https://raw.githubusercontent.com/MonoEven/ahk-hack-library/master/ahk_hack_single.ahk">{link_core}</a>
        <a href="https://github.com/MonoEven/ahk-hack-library/tree/master/lib/mcode">{link_mcode}</a>
        <a href="https://github.com/MonoEven/ahk-hack-library/tree/master/lib/ahk_live">{link_ahklive}</a>
        <a href="https://github.com/MonoEven/ahk-hack-library/tree/master/tests">{link_tests}</a>
      </div>
    </section>

    <article>
{body}
      <section id="appendix">
        <h2>{appendix}</h2>
        <p>{appendix_note}</p>
        <details>
          <summary>ahk_hack_single.ahk</summary>
          <pre><code>{MARKER}</code></pre>
        </details>
      </section>
    </article>
    </div>
  </main>
  <button class="sidebar-float" id="sidebarOpen" type="button" aria-label="Open sidebar">
    <span class="bar"></span><span class="bar"></span><span class="bar"></span>
  </button>

  <footer class="wrap">
    <div class="footer">
      {footer} ·
      <a href="https://github.com/MonoEven/ahk-hack-library">GitHub</a>
    </div>
  </footer>
  <script src="app.js?v=5"></script>
</body>
</html>
"""


def build() -> None:
    DOCS.mkdir(exist_ok=True)
    shutil.copy2(TEMPLATES / "style.css", DOCS / "style.css")
    shutil.copy2(TEMPLATES / "app.js", DOCS / "app.js")

    en_source = EN.read_text(encoding="utf-8")
    zh_source = ZH.read_text(encoding="utf-8")
    en_body, en_toc = parse(en_source)
    zh_body, zh_toc = parse(zh_source)

    en_lede = (
        "How an AutoHotkey v2 script reads the interpreter that is running it, "
        "rebuilds embedded x64 machine code, evaluates expressions in-process, "
        "loads script text from memory, and inspects remote AHK processes."
    )
    zh_lede = (
        "一个 AutoHotkey v2 脚本如何读取正在运行它的解释器、重建嵌入的 x64 "
        "机器码、在进程内求值、从内存加载脚本，并对远程 AHK 进程做在线内省。"
    )

    single_source = html.escape(SINGLE.read_text(encoding="utf-8"))
    en_page = page("en", "Inside AutoHotkey64.exe - ahk-hack", en_lede, en_body, en_toc)
    zh_page = page("zh", "AutoHotkey64.exe 内部 - ahk-hack", zh_lede, zh_body, zh_toc)

    if MARKER not in en_page or MARKER not in zh_page:
        raise RuntimeError("page template is missing the single-file marker")

    (DOCS / "index.html").write_text(en_page.replace(MARKER, single_source), encoding="utf-8")
    (DOCS / "index.zh.html").write_text(zh_page.replace(MARKER, single_source), encoding="utf-8")
    print("wrote docs/index.html")
    print("wrote docs/index.zh.html")
    print("site ready in docs/")


if __name__ == "__main__":
    build()
