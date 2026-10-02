#!/usr/bin/env bats
# Contract between options.json (what the wizard can emit) and install.sh
# (what the phone accepts). See docs/adr/0005-options-schema.md.

load helpers

setup() { tx_sandbox; }

# One line per value the wizard can produce: "<key>	<expected plan value>	<args...>",
# where args also set whatever that value's rules need (command.js exampleArgs).
wizard_values() {
    node -e '
        const C = require(process.argv[1]); const s = require(process.argv[2]);
        for (const o of s.options) {
            let vals;
            if (o.type === "choice" || o.type === "multi") vals = o.choices.map(c => c.value);
            else if (o.type === "bool") vals = [!o.default];
            else if (o.type === "int") vals = [o.min];
            else if (o.type === "list") vals = ["htop"];
            else if (o.type === "text") vals = [o.example];
            for (const v of vals) {
                const want = o.type === "bool" ? (v ? "yes" : "no") : String(v);
                console.log([o.id, want, ...C.exampleArgs(s, o.id, v)].join("	"));
            }
        }' "$REPO_ROOT/site/assets/command.js" "$REPO_ROOT/options.json"
}

@test "options.json is valid and every option has a flag, type and label" {
    run node -e '
        const o = require(process.argv[1]);
        for (const opt of o.options) {
            for (const k of ["id", "flag", "type", "label", "group"])
                if (!opt[k]) throw new Error(opt.id + " lacks " + k);
            if (!o.groups.some(g => g.id === opt.group)) throw new Error(opt.id + ": unknown group");
        }' "$REPO_ROOT/options.json"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "every group's documentation page exists" {
    for doc in $(node -e 'for (const g of require(process.argv[1]).groups) console.log(g.doc)' "$REPO_ROOT/options.json"); do
        [ -f "$REPO_ROOT/$doc" ] || { echo "missing $doc"; return 1; }
    done
}

@test "install.sh accepts every value the wizard can emit and plans it" {
    while IFS=$'	' read -r key want rest; do
        IFS=$'	' read -ra args <<<"$rest"
        run bash "$REPO_ROOT/install.sh" --dry-run "${args[@]}"
        [ "$status" -eq 0 ] || { echo "rejected: ${args[*]}: $output"; return 1; }
        grep -qE "^$key=(.*,)?$want(,.*)?$" <<<"$output" || { echo "${args[*]}: $key=$want not in plan: $output"; return 1; }
    done < <(wizard_values)
}

@test "every app the wizard offers maps to Termux packages in the installer" {
    for app in $(node -e 'for (const c of require(process.argv[1]).options.find(o => o.id === "apps").choices) console.log(c.value)' "$REPO_ROOT/options.json"); do
        run bash -c ". '$REPO_ROOT/setup/termux-linux-setup.sh'; app_packages '$app'"
        [ "$status" -eq 0 ] && [ -n "$output" ] || { echo "no packages for app: $app"; return 1; }
    done
}

@test "install.sh and the web wizard agree on every Linux and desktop combination" {
    cases=$(node -e '
        const s = require(process.argv[1]);
        const bases = s.options.find(o => o.id === "base").choices.map(c => c.value);
        const des = s.options.find(o => o.id === "de").choices.map(c => c.value);
        for (const b of bases) for (const d of des) console.log(b + " " + d);' "$REPO_ROOT/options.json")
    while read -r b d; do
        want=$(node -e '
            const C = require(process.argv[1]); const s = require(process.argv[2]);
            const st = C.defaultState(s); st.base = process.argv[3]; st.de = process.argv[4];
            process.stdout.write(C.planLines(s, C.applyRules(s, st)).join("\n"));' \
            "$REPO_ROOT/site/assets/command.js" "$REPO_ROOT/options.json" "$b" "$d")
        got=$(bash "$REPO_ROOT/install.sh" --dry-run --base "$b" --de "$d")
        [ "$want" = "$got" ] || { echo "== $b $d"; diff <(echo "$want") <(echo "$got"); return 1; }
    done <<<"$cases"
}
