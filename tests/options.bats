#!/usr/bin/env bats
# Contract between options.json (what the wizard can emit) and install.sh
# (what the phone accepts). See docs/adr/0005-options-schema.md.

load helpers

setup() { tx_sandbox; }

# Print "flag<TAB>type<TAB>value" for every value the wizard can produce.
wizard_values() {
    node -e '
        const o = require(process.argv[1]);
        for (const opt of o.options) {
            if (opt.type === "choice" || opt.type === "multi")
                for (const c of opt.choices) console.log([opt.flag, opt.type, c.value].join("\t"));
            else if (opt.type === "bool") console.log([opt.flag, "bool", ""].join("\t"));
            else if (opt.type === "int") console.log([opt.flag, "int", opt.min].join("\t"));
            else if (opt.type === "list") console.log([opt.flag, "list", "htop"].join("\t"));
        }' "$REPO_ROOT/options.json"
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
    while IFS=$'\t' read -r flag type value; do
        key="${flag#--}"
        if [ "$type" = bool-off ]; then
            key="${key#no-}"
            run bash "$REPO_ROOT/install.sh" --dry-run "$flag"
            [ "$status" -eq 0 ] || { echo "$flag rejected: $output"; return 1; }
            grep -qx "$key=no" <<<"$output" || { echo "$flag not in plan: $output"; return 1; }
        elif [ "$type" = bool ]; then
            run bash "$REPO_ROOT/install.sh" --dry-run "$flag"
            [ "$status" -eq 0 ] || { echo "$flag rejected: $output"; return 1; }
            grep -qx "$key=yes" <<<"$output" || { echo "$flag not in plan: $output"; return 1; }
        else
            run bash "$REPO_ROOT/install.sh" --dry-run "$flag" "$value"
            [ "$status" -eq 0 ] || { echo "$flag $value rejected: $output"; return 1; }
            grep -qE "^$key=(.*,)?$value(,.*)?$" <<<"$output" || { echo "$flag $value not in plan: $output"; return 1; }
        fi
    done < <(wizard_values)
}

@test "every app the wizard offers maps to Termux packages in the installer" {
    for app in $(node -e 'for (const c of require(process.argv[1]).options.find(o => o.id === "apps").choices) console.log(c.value)' "$REPO_ROOT/options.json"); do
        run bash -c ". '$REPO_ROOT/setup/termux-linux-setup.sh'; app_packages '$app'"
        [ "$status" -eq 0 ] && [ -n "$output" ] || { echo "no packages for app: $app"; return 1; }
    done
}

@test "the installer's defaults match options.json" {
    run bash "$REPO_ROOT/install.sh" --dry-run
    [ "$status" -eq 0 ]
    expected=$(node -e '
        for (const o of require(process.argv[1]).options) {
            const k = o.flag.slice(2);
            let v = o.default;
            if (o.type === "bool") v = v ? "yes" : "no";
            else if (Array.isArray(v)) v = v.join(",");
            else if (v === null) v = "auto";
            console.log(k + "=" + v);
        }' "$REPO_ROOT/options.json")
    while read -r line; do
        grep -qxF "$line" <<<"$output" || { echo "plan lacks default: $line"; echo "$output"; return 1; }
    done <<<"$expected"
}
