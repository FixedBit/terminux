// terminux wizard: turns the choices on the page into the command to paste
// into Termux. Pure functions, shared by the page and site/tests.
// SPDX-License-Identifier: Apache-2.0
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.TerminuxCommand = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const INSTALL_URL = "https://fixedbit.github.io/terminux/install.sh";

  const PATTERNS = {
    packages: /^[a-z0-9][a-z0-9+._-]*$/,
  };

  // Starting points; the user can change anything after picking one.
  const PRESETS = {
    recommended: {
      label: "Recommended",
      values: {},
    },
    developer: {
      label: "Developer",
      values: {
        apps: ["vscode", "firefox", "python", "nodejs", "build"],
        add: ["cli-essentials", "gh", "lazygit", "neovim", "tmux"],
        envs: ["dev"],
        ssh: true,
      },
    },
    ai: {
      label: "AI coding",
      values: {
        apps: ["vscode", "firefox", "python", "nodejs"],
        add: ["claude-code", "codex", "gemini-cli", "graperoot", "vscode-ai", "cli-essentials", "gh"],
      },
    },
    light: {
      label: "Light (older phones)",
      values: {
        de: "lxqt",
        apps: ["firefox"],
        tweaks: ["wakelock", "gpu-check", "phantom", "oneui-audio", "hidpi"],
        zsh: ["autosuggestions", "syntax-highlighting"],
      },
    },
  };

  function clone(v) { return Array.isArray(v) ? v.slice() : v; }

  function defaultState(schema) {
    const s = {};
    for (const o of schema.options) {
      if (o.type === "int") s[o.id] = o.default == null ? "" : String(o.default);
      else if (o.type === "list") s[o.id] = (o.default || []).join(",");
      else s[o.id] = clone(o.default);
    }
    return s;
  }

  function applyPreset(schema, name) {
    const s = defaultState(schema);
    const p = PRESETS[name];
    if (p) for (const [k, v] of Object.entries(p.values)) s[k] = clone(v);
    return s;
  }

  function sameSet(a, b) {
    return a.length === b.length && a.every(x => b.includes(x));
  }

  // One option -> flag tokens ([] when it's the default or invalid).
  function flagFor(o, value) {
    const name = o.flag.slice(2);
    switch (o.type) {
      case "choice":
        if (value === o.default) return [];
        return o.choices.some(c => c.value === value) ? [o.flag, value] : [];
      case "bool":
        if (!!value === !!o.default) return [];
        return [value ? o.flag : "--no-" + name];
      case "multi": {
        const allowed = o.choices.map(c => c.value);
        const picked = allowed.filter(v => (value || []).includes(v));
        if (sameSet(picked, o.default || [])) return [];
        return [o.flag, picked.length ? picked.join(",") : "none"];
      }
      case "int": {
        const v = String(value || "").trim();
        if (v === "") return [];
        const n = Number(v);
        if (!/^\d+$/.test(v) || n < o.min || n > o.max) return [];
        return [o.flag, v];
      }
      case "text": {
        const v = String(value || "").trim();
        if (v === "" || v === o.default) return [];
        if (!new RegExp(o.pattern).test(v)) return [];
        if (["root", "nobody", "daemon", "bin", "sys"].includes(v)) return [];
        return [o.flag, v];
      }
      case "list": {
        const items = String(value || "").split(",").map(x => x.trim()).filter(Boolean);
        if (!items.length) return [];
        const re = o.pattern ? new RegExp(o.pattern) : PATTERNS.packages;
        if (!items.every(x => re.test(x))) return [];
        return [o.flag, items.join(",")];
      }
    }
    return [];
  }

  function buildCommand(schema, state) {
    const args = [];
    for (const o of schema.options) args.push(...flagFor(o, state[o.id]));
    const base = `curl -fsSL ${INSTALL_URL} | bash`;
    return args.length ? `${base} -s -- ${args.join(" ")}` : base;
  }

  // Is this value usable? Lets the page mark a field as invalid.
  function isValid(o, value) {
    if (o.type === "int" || o.type === "text" || o.type === "list") {
      const v = String(value || "").trim();
      if (v === "" ) return true;
      return flagFor(o, value).length > 0 || v === String(o.default);
    }
    return true;
  }

  return { INSTALL_URL, PRESETS, defaultState, applyPreset, buildCommand, flagFor, isValid };
});
