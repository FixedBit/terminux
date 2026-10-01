// Tests for the wizard's command builder (site/assets/command.js).
// Run: node --test site/tests/
"use strict";
const test = require("node:test");
const assert = require("node:assert");
const path = require("path");
const { buildCommand, defaultState, PRESETS, INSTALL_URL } = require("../assets/command.js");
const options = require(path.join(__dirname, "../../options.json"));

const base = `curl -fsSL ${INSTALL_URL} | bash`;

test("defaults produce the bare command", () => {
  assert.strictEqual(buildCommand(options, defaultState(options)), base);
});

test("a changed choice becomes a flag", () => {
  const s = defaultState(options);
  s.de = "kde";
  assert.strictEqual(buildCommand(options, s), `${base} -s -- --de kde`);
});

test("multi options join with commas, in the order the schema lists them", () => {
  const s = defaultState(options);
  s.add = ["ollama", "claude-code"];
  assert.match(buildCommand(options, s), /--add claude-code,ollama$/);
});

test("emptying a multi option that has defaults says none", () => {
  const s = defaultState(options);
  s.tweaks = [];
  assert.match(buildCommand(options, s), /--tweaks none$/);
});

test("bool flags: on adds the flag, turning off an on-by-default one adds --no-", () => {
  const s = defaultState(options);
  s.wine = true;
  s.banner = false;
  const cmd = buildCommand(options, s);
  assert.match(cmd, / --wine( |$)/);
  assert.match(cmd, / --no-banner( |$)/);
});

test("empty number means automatic and is left out", () => {
  const s = defaultState(options);
  s.dpi = "";
  assert.strictEqual(buildCommand(options, s), base);
  s.dpi = "180";
  assert.match(buildCommand(options, s), /--dpi 180$/);
});

test("invalid values are left out rather than producing a broken command", () => {
  const s = defaultState(options);
  s.user = "Bad User; rm -rf ~";
  s.packages = "htop,$(reboot)";
  s.dpi = "9999";
  assert.strictEqual(buildCommand(options, s), base);
});

test("valid username and packages are included", () => {
  const s = defaultState(options);
  s.user = "jason";
  s.packages = "htop, neovim";
  assert.strictEqual(buildCommand(options, s), `${base} -s -- --packages htop,neovim --user jason`);
});

test("every preset only uses values the schema allows", () => {
  for (const [name, preset] of Object.entries(PRESETS)) {
    for (const [id, value] of Object.entries(preset.values)) {
      const opt = options.options.find(o => o.id === id);
      assert.ok(opt, `${name}: unknown option ${id}`);
      const allowed = (opt.choices || []).map(c => c.value);
      const values = Array.isArray(value) ? value : [value];
      if (opt.type === "choice" || opt.type === "multi") {
        for (const v of values) assert.ok(allowed.includes(v), `${name}: ${id}=${v} not allowed`);
      }
    }
  }
});

test("the command never contains anything secret-looking from the schema", () => {
  const s = defaultState(options);
  s.with = ["netbird"];
  assert.doesNotMatch(buildCommand(options, s), /KEY|SETUP|TOKEN/);
});
