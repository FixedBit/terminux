#!/usr/bin/env node
// Keeps the generated parts of the option schema in step with their sources:
//
//   options.json       --add choices from catalog.tsv, --envs from envs/*.env
//   lib/options.gen.sh  the whole schema as bash data, for install.sh and the
//                       terminal wizard (a fresh phone has no jq)
//
//   node tools/sync-options.js          rewrite both
//   node tools/sync-options.js --check  exit 1 if either is stale (CI)
//
// SPDX-License-Identifier: Apache-2.0
"use strict";
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const optionsPath = path.join(root, "options.json");
const genPath = path.join(root, "lib", "options.gen.sh");

function readCatalog() {
  const categories = [];
  const apps = [];
  for (const line of fs.readFileSync(path.join(root, "catalog.tsv"), "utf8").split("\n")) {
    if (line.startsWith("#@category\t")) {
      const [, id, title] = line.split("\t");
      categories.push({ id, title });
    } else if (line && !line.startsWith("#")) {
      const [value, category, target, , , label, help] = line.split("\t");
      apps.push({ value, label, help, category, target });
    }
  }
  return { categories, apps };
}

function readProfiles() {
  const dir = path.join(root, "envs");
  return fs.readdirSync(dir).filter(f => f.endsWith(".env")).sort().map(f => {
    const kv = {};
    for (const line of fs.readFileSync(path.join(dir, f), "utf8").split("\n")) {
      const m = /^([A-Z_]+)=(.*)$/.exec(line);
      if (m) kv[m[1]] = m[2];
    }
    const id = f.replace(/\.env$/, "");
    return { value: id, label: id, help: kv.DESCRIPTION || "" };
  });
}

function buildOptions(current) {
  const o = JSON.parse(JSON.stringify(current));
  const { categories, apps } = readCatalog();
  const add = o.options.find(x => x.id === "add");
  add.categories = categories;
  add.choices = apps;
  o.options.find(x => x.id === "envs").choices = readProfiles();
  return JSON.stringify(o, null, 2) + "\n";
}

// --- bash generation -------------------------------------------------------

const q = s => "'" + String(s == null ? "" : s).replace(/'/g, "'\\''") + "'";

// [{base:["termux"],de:[..]}, {envs:"*"}] -> "base=termux&de=xfce,lxqt;envs=*"
const whenExpr = when => (when || [])
  .map(alt => Object.entries(alt).map(([k, v]) => `${k}=${v === "*" ? "*" : v.join(",")}`).join("&"))
  .join(";");

function specFor(o) {
  const allowed = {
    choice: () => o.choices.map(c => c.value).join(" "),
    multi: () => o.choices.map(c => c.value).join(" "),
    bool: () => "",
    int: () => `${o.min}-${o.max}`,
    text: () => o.pattern,
    list: () => "",
  }[o.type]();
  let def = o.default;
  if (o.type === "bool") def = def ? "yes" : "no";
  else if (Array.isArray(def)) def = def.join(",");
  else if (def == null) def = o.type === "int" ? "auto" : "";
  return `${o.type}|${allowed}|${def}`;
}

function buildGen(schema) {
  const L = [];
  L.push("# shellcheck shell=bash disable=SC2034");
  L.push("# GENERATED from options.json by tools/sync-options.js. Do not edit.");
  L.push("");
  L.push(`TX_OPT_ORDER=(${schema.options.map(o => o.id).join(" ")})`);
  L.push(`TX_GROUPS=(${schema.groups.map(g => g.id).join(" ")})`);
  const assoc = (name, entries) => {
    L.push(`declare -gA ${name}=(`);
    for (const [k, v] of entries) L.push(`    [${q(k)}]=${q(v)}`);
    L.push(")");
  };
  assoc("TX_GROUP_TITLE", schema.groups.map(g => [g.id, g.title]));
  assoc("TX_GROUP_INTRO", schema.groups.map(g => [g.id, g.intro || ""]));
  assoc("TX_OPT_SPEC", schema.options.map(o => [o.id, specFor(o)]));
  assoc("TX_OPT_GROUP", schema.options.map(o => [o.id, o.group]));
  assoc("TX_OPT_LABEL", schema.options.map(o => [o.id, o.label]));
  assoc("TX_OPT_HELP", schema.options.map(o => [o.id, o.help || ""]));
  assoc("TX_OPT_WHEN", schema.options.filter(o => o.when).map(o => [o.id, whenExpr(o.when)]));
  const choices = schema.options.flatMap(o => (o.choices || []).map(c => [o, c]));
  assoc("TX_CHOICE_LABEL", choices.map(([o, c]) => [`${o.id}:${c.value}`, c.label]));
  assoc("TX_CHOICE_HELP", choices.map(([o, c]) => [`${o.id}:${c.value}`, c.help || ""]));
  assoc("TX_CHOICE_WHEN", choices.filter(([, c]) => c.when).map(([o, c]) => [`${o.id}:${c.value}`, whenExpr(c.when)]));
  assoc("TX_CHOICE_CATEGORY", choices.filter(([, c]) => c.category).map(([o, c]) => [`${o.id}:${c.value}`, c.category]));
  const add = schema.options.find(o => o.id === "add");
  assoc("TX_CATEGORY_TITLE", (add.categories || []).map(c => [c.id, c.title]));
  L.push(`TX_CATEGORIES=(${(add.categories || []).map(c => c.id).join(" ")})`);
  return L.join("\n") + "\n";
}

const currentOptions = fs.readFileSync(optionsPath, "utf8");
const nextOptions = buildOptions(JSON.parse(currentOptions));
const nextGen = buildGen(JSON.parse(nextOptions));
const currentGen = fs.existsSync(genPath) ? fs.readFileSync(genPath, "utf8") : "";

if (process.argv.includes("--check")) {
  const stale = [];
  if (currentOptions !== nextOptions) stale.push("options.json");
  if (currentGen !== nextGen) stale.push("lib/options.gen.sh");
  if (stale.length) {
    console.error(`${stale.join(" and ")} out of date. Run: node tools/sync-options.js`);
    process.exit(1);
  }
} else {
  if (currentOptions !== nextOptions) { fs.writeFileSync(optionsPath, nextOptions); console.log("options.json updated"); }
  if (currentGen !== nextGen) { fs.writeFileSync(genPath, nextGen); console.log("lib/options.gen.sh updated"); }
}
