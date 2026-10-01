# shellcheck shell=bash
# terminux -- terminux update: pull the latest terminux.
# SPDX-License-Identifier: Apache-2.0

cmd_update() {
    local repo="$TERMINUX_HOME"
    if ! git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        tx_fail "$repo isn't a git checkout, so it can't be updated in place."
        tx_hint "Reinstall: curl -fsSL https://raw.githubusercontent.com/FixedBit/terminux/main/install.sh | bash"
        return 1
    fi
    tx_info "Checking for updates"
    git -C "$repo" fetch --quiet || { tx_fail "Couldn't reach the terminux repository."; return 1; }

    local behind
    behind=$(git -C "$repo" rev-list --count 'HEAD..@{upstream}' 2>/dev/null || echo 0)
    if [ "$behind" -eq 0 ]; then
        tx_ok "terminux is up to date ($(git -C "$repo" log -1 --format=%h))."
        return 0
    fi
    if [ "${1:-}" = --check ]; then
        echo "$behind update(s) available:"
        git -C "$repo" log --format='  %h %s' 'HEAD..@{upstream}'
        echo "Install them with: terminux update"
        return 0
    fi
    if [ -n "$(git -C "$repo" status --porcelain)" ]; then
        tx_fail "You have local changes in $repo; not overwriting them."
        tx_hint "Keep them: git -C $repo stash, then terminux update, then git -C $repo stash pop"
        return 1
    fi

    local before; before=$(git -C "$repo" rev-parse HEAD)
    git -C "$repo" pull --quiet --ff-only || { tx_fail "Update failed (your checkout has diverged)."; return 1; }
    tx_ok "Updated to $(git -C "$repo" log -1 --format=%h):"
    git -C "$repo" log --format='  %h %s' "$before..HEAD"
}
