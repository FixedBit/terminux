#!/usr/bin/env bats
# tools/build-site.sh: the GitHub Pages site has everything it links to.

load helpers

setup() {
    OUT="$BATS_TEST_TMPDIR/_site"
    bash "$REPO_ROOT/tools/build-site.sh" "$OUT" >/dev/null
}

@test "the site has the wizard, the docs viewer and what they fetch" {
    for f in index.html wizard.html docs.html options.json install.sh assets/command.js assets/wizard.js assets/docs.js assets/style.css .nojekyll; do
        [ -e "$OUT/$f" ] || { echo "missing $f"; return 1; }
    done
}

@test "every page in the docs menu exists" {
    for p in $(grep -oE '\["[A-Za-z/-]+", "' "$REPO_ROOT/site/assets/docs.js" | cut -d'"' -f2); do
        [ -f "$OUT/docs/$p.md" ] || { echo "docs menu links to missing docs/$p.md"; return 1; }
    done
}

@test "every decision record is published" {
    for f in "$REPO_ROOT"/docs/adr/*.md; do
        [ -f "$OUT/docs/adr/$(basename "$f")" ] || { echo "missing adr $(basename "$f")"; return 1; }
    done
}

@test "the published installer is the repo's installer" {
    cmp "$REPO_ROOT/install.sh" "$OUT/install.sh"
}

@test "relative .md links in the docs point at pages that exist" {
    cd "$REPO_ROOT/docs"
    while IFS= read -r line; do
        file="${line%%:*}"; link="${line#*:}"
        target="$(dirname "$file")/${link%%#*}"
        [ -e "$target" ] || { echo "$file links to missing $link"; return 1; }
    done < <(grep -oE '\]\([^)#:]+\.md(#[^)]*)?\)' -r . | sed -E 's/\]\(([^)]*)\)/\1/')
}

@test "the site's pages are valid enough to parse" {
    node -e '
        const fs = require("fs");
        for (const f of ["index.html", "wizard.html", "docs.html"]) {
            const s = fs.readFileSync(process.argv[1] + "/" + f, "utf8");
            for (const tag of ["html", "head", "body", "main|div"]) {
                const open = (s.match(new RegExp("<(" + tag + ")[ >]", "g")) || []).length;
                const close = (s.match(new RegExp("</(" + tag + ")>", "g")) || []).length;
                if (open !== close) throw new Error(f + ": <" + tag + "> " + open + " open, " + close + " closed");
            }
        }' "$OUT"
}

@test "home, wizard and docs are separate pages that link to each other" {
    grep -q 'href="wizard.html"' "$OUT/index.html"
    grep -q 'href="docs.html"' "$OUT/index.html"
    grep -q 'id="wizard"' "$OUT/wizard.html"
    run grep -c 'id="wizard"' "$OUT/index.html"
    [ "$output" = 0 ]
    for f in index.html wizard.html docs.html; do
        for target in './' wizard.html docs.html; do
            grep -q "href=\"$target\"" "$OUT/$f" || { echo "$f has no link to $target"; return 1; }
        done
    done
}

@test "the wizard page only loads scripts and data that exist" {
    for src in $(grep -oE '(src|href)="assets/[^"]+"' "$OUT/wizard.html" | cut -d'"' -f2); do
        [ -f "$OUT/$src" ] || { echo "wizard.html needs missing $src"; return 1; }
    done
    grep -q 'fetch("options.json")' "$OUT/assets/wizard.js"
}

@test "links to the wizard from docs and the README point at wizard.html" {
    run grep -rn "fixedbit.github.io/terminux/)" "$REPO_ROOT/README.md" "$REPO_ROOT/docs"
    [ -z "$output" ] || { echo "links to the home page where the wizard is meant: $output"; return 1; }
}
