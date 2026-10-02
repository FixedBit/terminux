// The "when" rules as the web wizard applies them (site/assets/command.js).
"use strict";
const test = require("node:test");
const assert = require("node:assert");
const path = require("path");
const C = require("../assets/command.js");
const schema = require(path.join(__dirname, "../../options.json"));

const eff = changes => C.applyRules(schema, Object.assign(C.defaultState(schema), changes));

test("options that don't apply are emptied", () => {
  const s = eff({ base: "debian" });
  assert.strictEqual(s.wine, null);
  assert.strictEqual(eff({ de: "none" }).theme, null);
});

test("choices that don't apply are dropped from lists", () => {
  assert.deepStrictEqual(eff({ base: "ubuntu" }).apps, ["vscode", "vlc", "python"]);
  assert.ok(!eff({ de: "lxqt" }).tweaks.includes("touch"));
});

test("the username appears only when something needs an account", () => {
  assert.strictEqual(eff({}).user, null);
  assert.strictEqual(eff({ base: "debian" }).user, "user");
  assert.strictEqual(eff({ with: ["cursor"] }).user, "user");
  assert.strictEqual(eff({ envs: ["dev"] }).user, "user");
});

test("isApplicable and choiceApplies answer the page's questions", () => {
  const s = C.defaultState(schema);
  s.base = "debian";
  assert.strictEqual(C.isApplicable(schema, s, "wine"), false);
  assert.strictEqual(C.choiceApplies(schema, s, "apps", "firefox"), true);
  s.base = "ubuntu";
  assert.strictEqual(C.choiceApplies(schema, s, "apps", "firefox"), false);
});

test("the command never carries options that don't apply", () => {
  const s = C.defaultState(schema);
  s.base = "debian"; s.wine = true; s.user = "jason";
  const cmd = C.buildCommand(schema, s);
  assert.doesNotMatch(cmd, /--wine/);
  assert.match(cmd, /--base debian/);
  assert.match(cmd, /--user jason/);
});

test("a default on Ubuntu doesn't spell out an app list just because Firefox was dropped", () => {
  const s = C.defaultState(schema);
  s.base = "ubuntu";
  assert.doesNotMatch(C.buildCommand(schema, s), /--apps/);
});

test("the web command always says --yes, so the terminal wizard doesn't start", () => {
  assert.match(C.buildCommand(schema, C.defaultState(schema)), /bash -s -- --yes$/);
});

test("rules are explained in words", () => {
  assert.match(C.describeWhen(schema, "wine"), /only applies when .*termux/i);
});
