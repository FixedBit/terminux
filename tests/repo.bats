#!/usr/bin/env bats
# The repository ships what the code needs.

load helpers

@test "no file terminux needs is hidden by .gitignore" {
    cd "$REPO_ROOT"
    git rev-parse --git-dir >/dev/null 2>&1 || skip "not a git checkout"
    run git check-ignore envs/*.env catalog.tsv options.json install.sh bin/terminux lib/*.sh setup/*.sh site/index.html site/assets/*.js tools/*.sh tools/*.js
    [ "$status" -ne 0 ] || { echo "ignored by .gitignore: $output"; return 1; }
}

@test "scripts that are run directly are executable in git" {
    cd "$REPO_ROOT"
    git rev-parse --git-dir >/dev/null 2>&1 || skip "not a git checkout"
    for f in bin/terminux install.sh tools/build-site.sh tools/container-test.sh tools/sync-options.js setup/termux-linux-setup.sh setup/setup-homeassistant.sh; do
        mode=$(git ls-files -s "$f" | cut -d' ' -f1)
        [ "$mode" = 100755 ] || { echo "$f is $mode in git, not executable"; return 1; }
    done
}
