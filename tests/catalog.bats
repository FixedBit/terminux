#!/usr/bin/env bats
# catalog.tsv: the app catalog behind `terminux add`, the wizard and install.sh.

load helpers

CAT="$REPO_ROOT/catalog.tsv"
METHODS="pkg npm pip pipx script vsx terminux apt"
TARGETS="termux env"

setup() { tx_sandbox; }

# Data lines: id, category, target, method, spec, label, help (tab-separated)
rows() { grep -vE '^(#|$)' "$CAT"; }

@test "the catalog exists and every category has entries" {
    [ -f "$CAT" ]
    for c in ai dev media net; do
        [ "$(rows | awk -F'	' -v c="$c" '$2 == c' | wc -l)" -gt 0 ] || { echo "no $c entries"; return 1; }
    done
}

@test "every catalog row has seven fields" {
    while IFS= read -r line; do
        n=$(awk -F'\t' '{ print NF }' <<<"$line")
        [ "$n" -eq 7 ] || { echo "bad row ($n fields): $line"; return 1; }
    done < <(rows)
}

@test "ids are unique and look like ids" {
    dupes=$(rows | cut -f1 | sort | uniq -d)
    [ -z "$dupes" ] || { echo "duplicate ids: $dupes"; return 1; }
    rows | cut -f1 | while read -r id; do
        [[ "$id" =~ ^[a-z0-9][a-z0-9-]*$ ]] || { echo "bad id: $id"; return 1; }
    done
}

@test "methods and targets are ones terminux knows how to run" {
    while IFS=$'\t' read -r id cat target method spec label help; do
        [[ " $METHODS " == *" $method "* ]] || { echo "$id: unknown method $method"; return 1; }
        [[ " $TARGETS " == *" $target "* ]] || { echo "$id: unknown target $target"; return 1; }
    done < <(rows)
}

@test "installer scripts are only fetched over https" {
    while IFS=$'\t' read -r id cat target method spec label help; do
        [ "$method" = script ] || continue
        [[ "$spec" == https://* ]] || { echo "$id: $spec isn't https"; return 1; }
    done < <(rows)
}

@test "every category has a section in docs/APPS.md" {
    for c in $(rows | cut -f2 | sort -u); do
        grep -qiE "^## .*\($c\)" "$REPO_ROOT/docs/APPS.md" || { echo "docs/APPS.md lacks a '## ... ($c)' section"; return 1; }
    done
}

@test "options.json is in sync with the catalog (tools/sync-options.js --check)" {
    run node "$REPO_ROOT/tools/sync-options.js" --check
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "the wizard's --add choices are the whole catalog, each tagged with its category" {
    run node -e '
        const o = require(process.argv[1]).options.find(o => o.id === "add");
        for (const c of o.choices) console.log(c.value + "	" + c.category);' "$REPO_ROOT/options.json"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    want=$(rows | awk -F'	' '{ print $1 "	" $2 }' | sort)
    got=$(sort <<<"$output")
    [ -n "$want" ]
    [ "$want" = "$got" ] || { diff <(echo "$want") <(echo "$got"); return 1; }
}

@test "catalog entries that run terminux commands name real commands" {
    while IFS=$'\t' read -r id cat target method spec label help; do
        [ "$method" = terminux ] || continue
        cmd="${spec%% *}"
        run bash "$TX" "$cmd" --help-probe
        [[ "$output" != *"unknown command"* ]] || { echo "$id: terminux $cmd doesn't exist"; return 1; }
    done < <(rows)
}
