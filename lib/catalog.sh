# shellcheck shell=bash
# terminux -- terminux add: install apps from catalog.tsv.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/debian.sh
. "$TX_LIB/debian.sh"

TX_CATALOG="${TX_CATALOG:-$TX_LIB/../catalog.tsv}"

# Category titles come from the "#@category<TAB>id<TAB>title" lines.
declare -gA TX_CATEGORY_NAMES=()
while IFS=$'\t' read -r _ _id _title; do
    TX_CATEGORY_NAMES[$_id]="$_title"
done < <(grep '^#@category' "$TX_CATALOG")
unset _id _title

_tx_cat_rows() { grep -vE '^(#|$)' "$TX_CATALOG"; }

_tx_cat_categories() { grep '^#@category' "$TX_CATALOG" | cut -f2; }

# Print the catalog row for an id.
_tx_cat_row() { _tx_cat_rows | awk -F'\t' -v id="$1" '$1 == id { print; exit }'; }

_tx_cat_list() {
    local only="${1:-}" cat id _c target method spec label help
    while read -r cat; do
        [ -n "$only" ] && [ "$cat" != "$only" ] && continue
        printf '\n%s%s%s (%s)\n' "$TX_W" "${TX_CATEGORY_NAMES[$cat]:-$cat}" "$TX_C0" "$cat"
        while IFS=$'\t' read -r id _c target method spec label help; do
            [ "$_c" = "$cat" ] || continue
            printf '  %-14s %s %s- %s%s\n' "$id" "$label" "$TX_D" "$help" "$TX_C0"
        done < <(_tx_cat_rows)
    done < <(_tx_cat_categories)
}

# As your user inside the Debian environment.
_tx_cat_env_user() {
    proot-distro login debian --user "$(tx_debian_user)" --shared-tmp -- bash -c "$1"
}

tx_cat_install() {
    local row id _c target method spec label help
    row=$(_tx_cat_row "$1")
    [ -n "$row" ] || { tx_fail "'$1' isn't in the catalog (see: terminux add --list)"; return 2; }
    IFS=$'\t' read -r id _c target method spec label help <<< "$row"
    tx_step "Installing $label"

    if [ "$target" = env ] && [ "$method" != terminux ]; then
        tx_debian_installed || bash "$TX_LIB/../bin/terminux" app debian || return 1
    fi

    case "$method" in
        pkg)
            # shellcheck disable=SC2086 # spec is a list of packages
            pkg install -y $spec ;;
        npm)
            # Termux's own Node.js (a no-op when it's already current).
            pkg install -y nodejs >/dev/null || return 1
            npm install -g "$spec" ;;
        pip)
            pkg install -y python python-pip >/dev/null || return 1
            pip install --upgrade "$spec" ;;
        pipx)
            _tx_cat_env_user "sudo apt-get install -y pipx >/dev/null && pipx install $spec && pipx ensurepath >/dev/null" ;;
        apt)
            _tx_debian_root "DEBIAN_FRONTEND=noninteractive apt-get install -y $spec" ;;
        script)
            local tmp rc
            tmp=$(mktemp)
            curl -fsSL "$spec" > "$tmp" || { rm -f "$tmp"; tx_fail "couldn't download $spec"; return 1; }
            bash "$tmp"; rc=$?
            rm -f "$tmp"
            return "$rc" ;;
        vsx)
            tx_has code-oss || bash "$TX_LIB/../bin/terminux" app vscode || return 1
            local ext rc=0
            for ext in $spec; do
                code-oss --install-extension "$ext" || rc=1
            done
            return "$rc" ;;
        terminux)
            # shellcheck disable=SC2086 # spec is a terminux command line
            bash "$TX_LIB/../bin/terminux" $spec ;;
        *)
            tx_fail "$id: unknown install method '$method'"; return 1 ;;
    esac
}

# Pick a category, then apps by number.
_tx_cat_pick() {
    local -a cats ids
    local c i=1 choice n
    mapfile -t cats < <(_tx_cat_categories)
    echo
    for c in "${cats[@]}"; do
        printf '  %s%2d%s  %s\n' "$TX_B" "$i" "$TX_C0" "${TX_CATEGORY_NAMES[$c]:-$c}"
        i=$((i + 1))
    done
    read -rp "  Category: " choice || return 0
    [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#cats[@]}" ] \
        || { tx_warn "No such category."; return 2; }
    c="${cats[$((choice - 1))]}"

    mapfile -t ids < <(_tx_cat_rows | awk -F'\t' -v c="$c" '$2 == c { print $1 }')
    echo
    i=1
    for n in "${ids[@]}"; do
        local row; row=$(_tx_cat_row "$n")
        printf '  %s%2d%s  %s %s- %s%s\n' "$TX_B" "$i" "$TX_C0" "$(cut -f6 <<< "$row")" \
            "$TX_D" "$(cut -f7 <<< "$row")" "$TX_C0"
        i=$((i + 1))
    done
    read -rp "  Install which (numbers, separated by spaces): " choice || return 0
    local -a picked=()
    for n in $choice; do
        [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#ids[@]}" ] \
            && picked+=("${ids[$((n - 1))]}")
    done
    [ ${#picked[@]} -gt 0 ] || { tx_warn "Nothing picked."; return 0; }
    cmd_add "${picked[@]}"
}

cmd_add() {
    case "${1:-}" in
        --list|-l) _tx_cat_list "${2:-}"; return 0 ;;
        "")
            if [ -t 0 ] || [ "${TERMINUX_TTY:-0}" = 1 ]; then _tx_cat_pick; return; fi
            _tx_cat_list; return 0 ;;
    esac
    local id rc=0 unknown=0
    local -a failed=()
    for id in "$@"; do
        [ -n "$(_tx_cat_row "$id")" ] || { tx_fail "'$id' isn't in the catalog (see: terminux add --list)"; unknown=1; continue; }
        tx_cat_install "$id" || failed+=("$id")
    done
    [ "$unknown" = 1 ] && rc=2
    if [ ${#failed[@]} -gt 0 ]; then
        tx_fail "These didn't install: ${failed[*]}"
        rc=1
    fi
    return "$rc"
}
