#!/usr/bin/env node
// Regenerates the catalog-driven options in options.json from catalog.tsv
// and envs/*.env, so the wizard always offers exactly what terminux can
// install. Run after editing either; CI runs it with --check.
//
//   node tools/sync-options.js          rewrite options.json
//   node tools/sync-options.js --check  exit 1 if options.json is stale
//
// SPDX-License-Identifier: Apache-2.0
"use strict";
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const optionsPath = path.join(root, "options.json");

function readCatalog() {
  const categories = [];
  const apps = [];
  for (const line of fs.readFileSync(path.join(root, "catalog.tsv"), "utf8").split("\n")) {
    if (line.startsWith("#@category\t")) {
      const [, id, title] = line.split("\t");
      categories.push({ id, title });
    } else if (line && !line.startsWith("#")) {
      const [value, category, target, method, spec, label, help] = line.split("\t");
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
    return { value: f.replace(/\.env$/, ""), label: f.replace(/\.env$/, ""), help: kv.DESCRIPTION || "" };
  });
}

function build(options) {
  const { categories, apps } = readCatalog();
  const o = JSON.parse(JSON.stringify(options));
  o.groups = o.groups.filter(g => g.id !== "ai");
  if (!o.groups.some(g => g.id === "extras")) {
    o.groups.splice(o.groups.findIndex(g => g.id === "network"), 0,
      { id: "extras", title: "AI tools and more apps", doc: "docs/APPS.md" });
  }
  if (!o.groups.some(g => g.id === "envs")) {
    o.groups.splice(o.groups.findIndex(g => g.id === "network"), 0,
      { id: "envs", title: "Extra environments", doc: "docs/ENVIRONMENTS.md" });
  }
  const add = {
    id: "add", flag: "--add", group: "extras", type: "multi",
    label: "Apps from the catalog",
    help: "Anything here can also be added later with: terminux add",
    default: [], categories, choices: apps,
  };
  const envs = {
    id: "envs", flag: "--envs", group: "envs", type: "multi",
    label: "Environments to create",
    help: "Each becomes a proot environment named after its profile. Make more later with: terminux env create",
    default: [], choices: readProfiles(),
  };
  const rest = o.options.filter(x => !["ai", "add", "envs"].includes(x.id));
  const at = rest.findIndex(x => x.id === "ssh");
  o.options = [...rest.slice(0, at), add, envs, ...rest.slice(at)];
  return JSON.stringify(o, null, 2) + "\n";
}

const current = fs.readFileSync(optionsPath, "utf8");
const next = build(JSON.parse(current));
if (process.argv.includes("--check")) {
  if (current !== next) {
    console.error("options.json is out of date with catalog.tsv / envs/. Run: node tools/sync-options.js");
    process.exit(1);
  }
} else if (current !== next) {
  fs.writeFileSync(optionsPath, next);
  console.log("options.json updated");
}
