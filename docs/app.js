(() => {
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

  document.querySelectorAll("pre").forEach((pre) => {
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
