(() => {
  const body = document.body;
  const openBtn = document.getElementById("sidebarOpen");
  const closeBtn = document.getElementById("sidebarClose");
  const isDesktop = () => window.innerWidth >= 1024;

  const applySidebar = () => {
    if (!isDesktop()) {
      body.classList.remove("sidebar-collapsed");
      body.classList.remove("sidebar-open");
      return;
    }
    body.classList.remove("sidebar-open");
    const collapsed = localStorage.getItem("ahk-sidebar") === "1";
    body.classList.toggle("sidebar-collapsed", collapsed);
  };

  if (openBtn) {
    openBtn.addEventListener("click", () => {
      if (isDesktop()) {
        body.classList.remove("sidebar-collapsed");
        localStorage.setItem("ahk-sidebar", "0");
      } else {
        body.classList.add("sidebar-open");
      }
    });
  }
  if (closeBtn) {
    closeBtn.addEventListener("click", () => {
      if (isDesktop()) {
        body.classList.add("sidebar-collapsed");
        localStorage.setItem("ahk-sidebar", "1");
      } else {
        body.classList.remove("sidebar-open");
      }
    });
  }
  window.addEventListener("resize", applySidebar);
  applySidebar();

  const tocLinks = Array.from(document.querySelectorAll("#toc a"));
  const headings = tocLinks
    .map((a) => document.querySelector(a.getAttribute("href")))
    .filter(Boolean);
  const setActive = () => {
    let current = headings[0];
    for (const h of headings) {
      if (h.getBoundingClientRect().top <= 130) current = h;
    }
    if (!current) return;
    for (const a of tocLinks) {
      a.classList.toggle("active", a.getAttribute("href") === "#" + current.id);
    }
  };
  window.addEventListener("scroll", setActive, { passive: true });
  setActive();

  const progress = document.querySelector(".progress");
  const updateProgress = () => {
    const top = window.scrollY;
    const height = document.documentElement.scrollHeight - window.innerHeight;
    if (progress && height > 0) {
      progress.style.width = Math.min(100, (top / height) * 100) + "%";
    }
  };
  window.addEventListener("scroll", updateProgress, { passive: true });
  window.addEventListener("resize", updateProgress);
  updateProgress();

  const AHK_KEYWORDS = new Set([
    "Abs", "Array", "Break", "Buffer", "Catch", "Class", "Continue",
    "DllCall", "Else", "ExitApp", "FileAppend", "FileDelete", "FileExist",
    "FileRead", "Finally", "For", "Format", "Global", "If", "Local",
    "Loop", "Map", "MsgBox", "NumGet", "NumPut", "Return", "SetWorkingDir",
    "Static", "StrGet", "StrLen", "StrPut", "SubStr", "Throw", "Try",
    "While", "false", "true", "this"
  ]);

  const escapeHtml = (s) =>
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  const langOf = (pre) => {
    const raw = pre.textContent.trimStart();
    if (/^(python |& )/.test(raw) || /^D:\\\\/.test(raw)) return "ps";
    if (/^(;|#Include|MsgBox|class |[A-Za-z_][\w]*\(|\.Ptr\b)/m.test(raw) && raw.includes("MCode"))
      return "ahk";
    if (/#Include|MsgBox|NumGet|StrPut|FileAppend|:=|\.Ptr\b/.test(raw)) return "ahk";
    return "text";
  };

  const tokenize = (pre) => {
    const code = pre.querySelector("code");
    if (!code || pre.dataset.highlighted) return;
    const raw = code.textContent;
    const lang = langOf(pre);
    const isIdent = (c) => /[A-Za-z0-9_]/.test(c);
    let html = "";
    let i = 0;
    while (i < raw.length) {
      const ch = raw[i];
      if ((lang === "ahk" && ch === ";") || (lang === "ps" && ch === "#")) {
        const start = i;
        while (i < raw.length && raw[i] !== "\n") i++;
        html += '<span class="tok-cmt">' + escapeHtml(raw.slice(start, i)) + "</span>";
        continue;
      }
      if (ch === '"' || ch === "'") {
        const quote = ch;
        const start = i++;
        while (i < raw.length) {
          if (raw[i] === "\\" || raw[i] === "`") {
            i += 2;
            continue;
          }
          if (raw[i] === quote) {
            i++;
            break;
          }
          i++;
        }
        html += '<span class="tok-str">' + escapeHtml(raw.slice(start, i)) + "</span>";
        continue;
      }
      if (ch === "0" && raw[i + 1] === "x") {
        const start = i;
        i += 2;
        while (i < raw.length && /[0-9a-fA-F]/.test(raw[i])) i++;
        html += '<span class="tok-num">' + escapeHtml(raw.slice(start, i)) + "</span>";
        continue;
      }
      if (/[0-9]/.test(ch)) {
        const start = i;
        while (i < raw.length && /[0-9.]/.test(raw[i])) i++;
        html += '<span class="tok-num">' + escapeHtml(raw.slice(start, i)) + "</span>";
        continue;
      }
      if (/[A-Za-z_]/.test(ch)) {
        const start = i;
        while (i < raw.length && isIdent(raw[i])) i++;
        const word = raw.slice(start, i);
        if (AHK_KEYWORDS.has(word)) {
          html += '<span class="tok-kw">' + escapeHtml(word) + "</span>";
        } else if (raw[i] === "(") {
          html += '<span class="tok-fn">' + escapeHtml(word) + "</span>";
        } else {
          html += escapeHtml(word);
        }
        continue;
      }
      html += escapeHtml(ch);
      i++;
    }
    code.innerHTML = html;
    pre.dataset.highlighted = "1";
  };

  document.querySelectorAll("pre").forEach((pre) => {
    tokenize(pre);
    const button = document.createElement("button");
    button.type = "button";
    button.className = "copy";
    button.textContent = "copy";
    button.setAttribute("aria-label", "Copy code");
    button.addEventListener("click", async () => {
      const text = pre.innerText;
      try {
        await navigator.clipboard.writeText(text);
        button.textContent = "copied";
      } catch {
        button.textContent = "select";
        const range = document.createRange();
        range.selectNodeContents(pre);
        window.getSelection().removeAllRanges();
        window.getSelection().addRange(range);
      }
      setTimeout(() => {
        button.textContent = "copy";
      }, 1200);
    });
    pre.style.position = "relative";
    pre.appendChild(button);
  });
})();
