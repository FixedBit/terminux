// terminux wizard: the option rules and the command to paste into Termux.
// Pure functions, shared by the page, the tests and the bash rule engine's
// cross-check (tests/options.bats). Mirrors lib/options.sh.
// SPDX-License-Identifier: Apache-2.0
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory();
  else root.TerminuxCommand = factory();
})(typeof self !== "undefined" ? self : this, function () {
  "use strict";

  const INSTALL_URL = "https://fixedbit.github.io/terminux/install.sh";
  const SYSTEM_USERS = ["root", "nobody", "daemon", "bin", "sys"];
  const PKG_RE = /^[a-z0-9][a-z0-9+._-]*$/;

  // Starting points; the user can change anything after picking one.
  const PRESETS = {
    recommended: { label: "Recommended", values: {} },
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
    terminal: {
      label: "Terminal only",
      values: { de: "none", apps: ["python", "nodejs", "build"], add: ["cli-essentials", "neovim", "tmux"] },
    },
  };

  const clone = v => (Array.isArray(v) ? v.slice() : v);
  const opt = (schema, id) => schema.options.find(o => o.id === id);
  const asList = v => (Array.isArray(v) ? v : v == null || v === "" ? [] : [v]);

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

  // --- rules (keep in step with lib/options.sh) ----------------------------

  function altOk(alt, state) {
    return Object.entries(alt).every(([k, want]) => {
      const have = asList(state[k]).map(String);
      if (want === "*") return have.length > 0;
      return have.some(v => want.includes(v));
    });
  }
  const whenOk = (when, state) => !when || when.some(alt => altOk(alt, state));

  function choiceApplies(schema, state, id, value) {
    const c = (opt(schema, id).choices || []).find(x => x.value === value);
    return !!c && whenOk(c.when, state);
  }

  function withImplied(schema, state) {
    const w = asList(state.with);
    if (w.some(v => v === "vscode-ms" || v === "cursor") && !w.includes("debian")
        && choiceApplies(schema, state, "with", "debian"))
      return ["debian", ...w];
    return w;
  }

  // The state that would actually be installed: what doesn't apply is gone.
  function applyRules(schema, state) {
    const s = Object.assign({}, state);
    s.with = withImplied(schema, s);
    for (const o of schema.options) {           // pass 1: choices
      if (o.type === "multi")
        s[o.id] = o.choices.map(c => c.value).filter(v => asList(s[o.id]).includes(v) && whenOk(o.choices.find(c => c.value === v).when, s));
    }
    for (const o of schema.options) {           // pass 2: whole options
      if (!whenOk(o.when, s)) s[o.id] = null;
    }
    return s;
  }

  const isApplicable = (schema, state, id) => whenOk(opt(schema, id).when, applyRules(schema, state));

  function describeWhen(schema, id, value) {
    const o = opt(schema, id);
    const when = value === undefined ? o.when : (o.choices.find(c => c.value === value) || {}).when;
    if (!when) return "";
    const words = when.map(alt => Object.entries(alt).map(([k, v]) =>
      v === "*" ? `--${k} is set` : `--${k} is ${v.join(" or ")}`).join(" and ")).join(", or ");
    return "only applies when " + words;
  }

  // install.sh --dry-run's output for an effective state.
  function planLines(schema, eff) {
    return schema.options.map(o => {
      let v = eff[o.id];
      if (v == null) v = "";
      else if (o.type === "bool") v = v ? "yes" : "no";
      else if (Array.isArray(v)) v = v.join(",");
      else if (o.type === "int" && v === "") v = "auto";
      return `${o.id}=${v}`;
    });
  }

  // --- the command ---------------------------------------------------------

  // One option -> flag tokens, given the effective state ([] = leave it out).
  function flagFor(o, value, eff) {
    if (value == null) return [];
    switch (o.type) {
      case "choice":
        if (value === o.default) return [];
        return o.choices.some(c => c.value === value) ? [o.flag, value] : [];
      case "bool":
        if (!!value === !!o.default) return [];
        return [value ? o.flag : "--no-" + o.flag.slice(2)];
      case "multi": {
        const picked = o.choices.map(c => c.value).filter(v => (value || []).includes(v));
        // Compare with the default as it applies here, so dropping Firefox on
        // Ubuntu doesn't make the command spell out the whole list.
        const effDefault = (o.default || []).filter(v => !eff || whenOk((o.choices.find(c => c.value === v) || {}).when, eff));
        if (picked.length === effDefault.length && picked.every(v => effDefault.includes(v))) return [];
        return [o.flag, picked.length ? picked.join(",") : "none"];
      }
      case "int": {
        const v = String(value).trim();
        if (v === "" || !/^\d+$/.test(v) || +v < o.min || +v > o.max) return [];
        return [o.flag, v];
      }
      case "text": {
        const v = String(value).trim();
        if (v === "" || v === o.default || !new RegExp(o.pattern).test(v) || SYSTEM_USERS.includes(v)) return [];
        return [o.flag, v];
      }
      case "list": {
        const items = String(value).split(",").map(x => x.trim()).filter(Boolean);
        if (!items.length || !items.every(x => PKG_RE.test(x))) return [];
        return [o.flag, items.join(",")];
      }
    }
    return [];
  }

  function buildCommand(schema, state) {
    const eff = applyRules(schema, state);
    const args = [];
    for (const o of schema.options) {
      // vscode-ms/cursor bring Debian in on their own; don't spell it out.
      let v = eff[o.id];
      if (o.id === "with" && Array.isArray(v) && !asList(state.with).includes("debian"))
        v = v.filter(x => x !== "debian" || asList(state.with).includes("debian"));
      args.push(...flagFor(o, v, eff));
    }
    // Always --yes: a command from this page never stops to ask questions.
    return `curl -fsSL ${INSTALL_URL} | bash -s -- ${args.concat("--yes").join(" ")}`;
  }

  function isValid(o, value) {
    if (o.type === "int" || o.type === "text" || o.type === "list") {
      const v = String(value == null ? "" : value).trim();
      if (v === "" || v === String(o.default)) return true;
      return flagFor(o, value, null).length > 0;
    }
    return true;
  }

  // Flags that make <id>=<value> apply: the option itself plus whatever its
  // rules need (first alternative, first allowed values). For tests.
  function exampleArgs(schema, id, value) {
    const args = [];
    const need = alt => {
      for (const [k, v] of Object.entries(alt || {})) {
        if (k === id) continue;
        const ko = opt(schema, k);
        const pick = v === "*" ? ko.choices[0].value : v[0];
        args.push(ko.flag, pick);
      }
    };
    const o = opt(schema, id);
    need((o.when || [])[0]);
    if (o.choices) need(((o.choices.find(c => c.value === value) || {}).when || [])[0]);
    if (o.type === "bool") args.push(value === false ? "--no-" + o.flag.slice(2) : o.flag);
    else args.push(o.flag, String(value));
    return args;
  }

  return {
    INSTALL_URL, PRESETS, defaultState, applyPreset, applyRules, isApplicable,
    choiceApplies, describeWhen, planLines, buildCommand, flagFor, isValid, exampleArgs,
  };
});
