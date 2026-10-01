// terminux wizard page: renders options.json as a form and keeps the
// command in sync. The command logic lives in command.js.
// SPDX-License-Identifier: Apache-2.0
(function () {
  "use strict";
  const C = window.TerminuxCommand;
  let schema = null;
  let state = null;

  const $ = (sel, el = document) => el.querySelector(sel);
  const h = (tag, attrs = {}, ...kids) => {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (v === false || v == null) continue;
      if (k === "text") el.textContent = v;
      else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
      else el.setAttribute(k, v === true ? "" : v);
    }
    for (const k of kids) if (k != null) el.append(k);
    return el;
  };

  function update() {
    $("#command").textContent = C.buildCommand(schema, state);
    // The choices travel in the address, so a link reproduces the setup.
    const params = new URLSearchParams();
    for (const o of schema.options) {
      const t = C.flagFor(o, state[o.id]);
      if (t.length) params.set(o.id, t.length > 1 ? t[1] : (t[0].startsWith("--no-") ? "no" : "yes"));
    }
    const q = params.toString();
    history.replaceState(null, "", q ? "?" + q : location.pathname);
    for (const o of schema.options) {
      const input = document.getElementById("opt-" + o.id);
      if (input && input.tagName === "INPUT" && input.type !== "checkbox") {
        input.toggleAttribute("aria-invalid", !C.isValid(o, state[o.id]));
      }
    }
  }

  function loadFromAddress() {
    const params = new URLSearchParams(location.search);
    for (const o of schema.options) {
      if (!params.has(o.id)) continue;
      const v = params.get(o.id);
      if (o.type === "multi") state[o.id] = v === "none" ? [] : v.split(",");
      else if (o.type === "bool") state[o.id] = v === "yes";
      else state[o.id] = v;
    }
  }

  function docLink(group) {
    if (!group.doc) return null;
    const page = group.doc.replace(/^docs\//, "").replace(/\.md$/, "");
    return h("a", { class: "group-doc", href: "docs.html?page=" + encodeURIComponent(page) }, "How this works");
  }

  function choiceField(o) {
    const box = h("div", { class: "choices", role: "radiogroup", "aria-label": o.label });
    for (const c of o.choices) {
      const id = `opt-${o.id}-${c.value}`;
      box.append(h("label", { class: "choice", for: id },
        h("input", { type: "radio", name: o.id, id, value: c.value, checked: state[o.id] === c.value,
          onchange: () => { state[o.id] = c.value; update(); } }),
        h("span", { class: "choice-label", text: c.label }),
        c.help ? h("span", { class: "choice-help", text: c.help }) : null));
    }
    return box;
  }

  function multiField(o) {
    const wrap = h("div", { class: "multi" });
    const toggle = (value, on) => {
      const set = new Set(state[o.id] || []);
      on ? set.add(value) : set.delete(value);
      state[o.id] = o.choices.map(c => c.value).filter(v => set.has(v));
      update();
    };
    const makeBox = list => {
      const box = h("div", { class: "checks" });
      for (const c of list) {
        const id = `opt-${o.id}-${c.value}`;
        box.append(h("label", { class: "check", for: id },
          h("input", { type: "checkbox", id, value: c.value, checked: (state[o.id] || []).includes(c.value),
            onchange: e => toggle(c.value, e.target.checked) }),
          h("span", { class: "choice-label", text: c.label }),
          c.target === "env" ? h("span", { class: "where", text: "Debian" }) : null,
          c.help ? h("span", { class: "choice-help", text: c.help }) : null));
      }
      return box;
    };
    if (o.categories) {
      for (const cat of o.categories) {
        const list = o.choices.filter(c => c.category === cat.id);
        if (!list.length) continue;
        wrap.append(h("h4", { class: "category", text: cat.title }), makeBox(list));
      }
    } else {
      wrap.append(makeBox(o.choices));
    }
    return wrap;
  }

  function boolField(o) {
    const id = "opt-" + o.id;
    return h("label", { class: "switch", for: id },
      h("input", { type: "checkbox", id, role: "switch", checked: !!state[o.id],
        onchange: e => { state[o.id] = e.target.checked; update(); } }),
      h("span", { class: "choice-label", text: o.label }),
      o.help ? h("span", { class: "choice-help", text: o.help }) : null);
  }

  function textField(o) {
    const id = "opt-" + o.id;
    const attrs = { id, name: o.id, autocomplete: "off", spellcheck: "false",
      value: state[o.id] == null ? "" : state[o.id],
      oninput: e => { state[o.id] = e.target.value; update(); } };
    if (o.type === "int") Object.assign(attrs, { type: "number", inputmode: "numeric", min: o.min, max: o.max, placeholder: "automatic" });
    else attrs.type = "text";
    if (o.type === "list") attrs.placeholder = "htop, neovim, tmux";
    return h("div", { class: "text-field" },
      h("label", { for: id, text: o.label }),
      h("input", attrs),
      o.help ? h("p", { class: "choice-help", text: o.help }) : null);
  }

  function render() {
    const groups = $("#groups");
    groups.replaceChildren();
    for (const g of schema.groups) {
      const opts = schema.options.filter(o => o.group === g.id);
      if (!opts.length) continue;
      const sec = h("fieldset", { class: "group", id: "group-" + g.id },
        h("legend", {}, h("span", { text: g.title })), docLink(g));
      for (const o of opts) {
        const field = h("div", { class: "field field-" + o.type });
        if (o.type !== "bool" && o.type !== "int" && o.type !== "text" && o.type !== "list") {
          field.append(h("h3", { class: "field-label", text: o.label }));
          if (o.help) field.append(h("p", { class: "field-help", text: o.help }));
        }
        if (o.type === "choice") field.append(choiceField(o));
        else if (o.type === "multi") field.append(multiField(o));
        else if (o.type === "bool") field.append(boolField(o));
        else field.append(textField(o));
        sec.append(field);
      }
      groups.append(sec);
    }
  }

  function renderPresets() {
    const row = $("#presets");
    for (const [name, p] of Object.entries(C.PRESETS)) {
      row.append(h("button", { type: "button", class: "preset", "data-preset": name, text: p.label,
        onclick: () => {
          state = C.applyPreset(schema, name);
          for (const b of row.children) b.setAttribute("aria-pressed", b.dataset.preset === name);
          render(); update();
        } }));
    }
  }

  function toast(msg) {
    const t = $("#toast");
    t.textContent = msg;
    t.classList.add("show");
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => t.classList.remove("show"), 1800);
  }

  $("#copy").addEventListener("click", async () => {
    const text = $("#command").textContent;
    try {
      await navigator.clipboard.writeText(text);
      toast("Copied. Paste it into Termux.");
    } catch {
      const r = document.createRange();
      r.selectNodeContents($("#command"));
      const sel = getSelection(); sel.removeAllRanges(); sel.addRange(r);
      toast("Selected. Copy it, then paste into Termux.");
    }
  });

  fetch("options.json")
    .then(r => { if (!r.ok) throw new Error(r.status); return r.json(); })
    .then(s => {
      schema = s;
      state = C.defaultState(schema);
      loadFromAddress();
      renderPresets();
      render();
      update();
    })
    .catch(() => {
      $("#groups").replaceChildren(h("p", { class: "load-error",
        text: "Couldn't load the options. Reload the page, or run the installer with its defaults using the command shown." }));
    });
})();
