// terminux docs viewer: renders the Markdown in docs/ on GitHub Pages.
// SPDX-License-Identifier: Apache-2.0
(function () {
  "use strict";
  const REPO = "https://github.com/FixedBit/terminux/blob/main/";

  // The table of contents, and the only pages this viewer will load.
  const SECTIONS = [
    ["Using terminux", [
      ["GETTING-STARTED", "Getting started"],
      ["DESKTOPS", "Desktops"],
      ["DISPLAY", "Display and look"],
      ["DEVICE-TWEAKS", "Device tweaks"],
      ["APPS", "Apps and AI tools"],
      ["ENVIRONMENTS", "Environments"],
      ["SHELL", "Account and shell"],
      ["NETBIRD", "NetBird mesh"],
      ["TROUBLESHOOTING", "Troubleshooting"],
      ["GALAXY-FOLD", "Galaxy Z Fold notes"],
    ]],
    ["The project", [
      ["ARCHITECTURE", "Architecture"],
      ["adr/README", "Design decisions"],
      ["DEVELOPMENT", "Development"],
      ["CHANGELOG", "Changelog"],
      ["CREDITS", "Credits"],
    ]],
  ];
  const known = new Set(SECTIONS.flatMap(([, pages]) => pages.map(([p]) => p)));
  const isAdr = p => /^adr\/\d{4}-[a-z0-9-]+$/.test(p);

  const params = new URLSearchParams(location.search);
  let page = params.get("page") || "GETTING-STARTED";
  if (!known.has(page) && !isAdr(page)) page = "GETTING-STARTED";

  function nav() {
    const el = document.getElementById("docs-nav");
    for (const [title, pages] of SECTIONS) {
      const h = document.createElement("h2");
      h.textContent = title;
      const ul = document.createElement("ul");
      for (const [p, label] of pages) {
        const a = document.createElement("a");
        a.href = "docs.html?page=" + encodeURIComponent(p);
        a.textContent = label;
        if (p === page || (p === "adr/README" && isAdr(page))) a.setAttribute("aria-current", "page");
        const li = document.createElement("li");
        li.append(a);
        ul.append(li);
      }
      el.append(h, ul);
    }
  }

  // Resolve a link written for GitHub's file view against the current page.
  function rewrite(href) {
    if (!href || /^(https?:|mailto:|#)/.test(href)) return href;
    const [path, hash] = href.split("#");
    const base = page.includes("/") ? page.slice(0, page.lastIndexOf("/") + 1) : "";
    const parts = (base + path).split("/");
    const out = [];
    for (const p of parts) {
      if (p === "..") out.length ? out.pop() : out.push("..");
      else if (p && p !== ".") out.push(p);
    }
    const target = out.join("/");
    if (target.startsWith("..")) {
      // Outside docs/: the repo root on GitHub.
      return REPO + target.replace(/^(\.\.\/)+/, "") + (hash ? "#" + hash : "");
    }
    const name = target.replace(/\.md$/, "");
    if (/\.md$/.test(target) && (known.has(name) || isAdr(name)))
      return "docs.html?page=" + encodeURIComponent(name) + (hash ? "#" + hash : "");
    if (/\.md$/.test(target) && name.endsWith("/README")) return "docs.html?page=" + encodeURIComponent(name);
    return REPO + "docs/" + target + (hash ? "#" + hash : "");
  }

  async function load() {
    const doc = document.getElementById("doc");
    try {
      const r = await fetch("docs/" + page + ".md");
      if (!r.ok) throw new Error(r.status);
      const md = await r.text();
      doc.innerHTML = DOMPurify.sanitize(marked.parse(md, { gfm: true }));
      for (const a of doc.querySelectorAll("a[href]")) a.setAttribute("href", rewrite(a.getAttribute("href")));
      for (const h of doc.querySelectorAll("h2, h3")) {
        if (!h.id) h.id = h.textContent.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
      }
      const h1 = doc.querySelector("h1");
      document.title = (h1 ? h1.textContent + " – " : "") + "terminux docs";
      if (location.hash) document.getElementById(location.hash.slice(1))?.scrollIntoView();
    } catch {
      doc.innerHTML = "";
      const p = document.createElement("p");
      p.append("This page didn't load. ");
      const a = document.createElement("a");
      a.href = REPO + "docs/" + page + ".md";
      a.textContent = "Read it on GitHub instead.";
      p.append(a);
      doc.append(p);
    }
  }

  nav();
  load();
})();
