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
    for c in ai; do
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

@test "the wizard's --ai choices are exactly the catalog's ai category" {
    want=$(rows | awk -F'\t' '$2 == "ai" { print $1 }' | sort)
    run node -e 'for (const c of require(process.argv[1]).options.find(o => o.id === "ai").choices) console.log(c.value)' "$REPO_ROOT/options.json"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    got=$(sort <<<"$output")
    [ -n "$want" ]
    [ "$want" = "$got" ] || { diff <(echo "$want") <(echo "$got"); return 1; }
}
