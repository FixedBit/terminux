# shellcheck shell=bash
# terminux -- install options: parsing and validation for install.sh.
# SPDX-License-Identifier: Apache-2.0
#
# Mirrors options.json in plain bash, because a fresh phone has no jq.
# tests/options.bats fails if the two disagree. See docs/adr/0005.

# flag -> "type|allowed values|default"   (types: choice multi bool int list)
declare -gA TX_OPT_SPEC=(
    [de]="choice|xfce lxqt mate kde|xfce"
    [wine]="bool||no"
    [theme]="choice|dark light|dark"
    [dpi]="int|72-320|auto"
    [tweaks]="multi|wakelock gpu-check phantom oneui-audio touch hidpi|wakelock,gpu-check,phantom,oneui-audio,touch,hidpi"
    [apps]="multi|vscode firefox chromium vlc gimp libreoffice python nodejs build|vscode,firefox,vlc,python"
    [packages]="list||"
    [with]="multi|vscode-ms cursor netbird|"
    [ssh]="bool||no"
)
# Plan output order (matches options.json).
TX_OPT_ORDER=(de wine theme dpi tweaks apps packages with ssh)

TX_PKG_NAME_RE='^[a-z0-9][a-z0-9+._-]*$'

declare -gA TX_PLAN=()

tx_opt_defaults() {
    local k
    for k in "${TX_OPT_ORDER[@]}"; do
        TX_PLAN[$k]="${TX_OPT_SPEC[$k]##*|}"
    done
}

_tx_opt_bad() { tx_fail "$1"; return 2; }

# Validate and store one option. Returns 2 on invalid input.
tx_opt_set() {
    local key="$1" value="$2" spec type allowed item
    spec="${TX_OPT_SPEC[$key]:-}"
    [ -n "$spec" ] || { _tx_opt_bad "unknown option: --$key"; return 2; }
    type="${spec%%|*}"
    allowed="${spec#*|}"; allowed="${allowed%|*}"

    case "$type" in
        bool)
            TX_PLAN[$key]=yes ;;
        choice)
            [[ " $allowed " == *" $value "* ]] \
                || { _tx_opt_bad "--$key: '$value' is not one of: $allowed"; return 2; }
            TX_PLAN[$key]="$value" ;;
        multi)
            # "none" is how the wizard says "all unchecked".
            [ "$value" = none ] && { TX_PLAN[$key]=""; return 0; }
            local -a items
            IFS=',' read -ra items <<< "$value"
            for item in "${items[@]}"; do
                [[ " $allowed " == *" $item "* ]] \
                    || { _tx_opt_bad "--$key: '$item' is not one of: $allowed"; return 2; }
            done
            TX_PLAN[$key]="$value" ;;
        int)
            local lo="${allowed%-*}" hi="${allowed#*-}"
            [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge "$lo" ] && [ "$value" -le "$hi" ] \
                || { _tx_opt_bad "--$key: '$value' must be a number from $lo to $hi"; return 2; }
            TX_PLAN[$key]="$value" ;;
        list)
            local -a items
            IFS=',' read -ra items <<< "$value"
            for item in "${items[@]}"; do
                [[ "$item" =~ $TX_PKG_NAME_RE ]] \
                    || { _tx_opt_bad "--$key: '$item' is not a valid package name"; return 2; }
            done
            TX_PLAN[$key]="$value" ;;
    esac
}

# Is --<key> a flag that takes no value?
tx_opt_is_bool() { [ "${TX_OPT_SPEC[$1]%%|*}" = bool ]; }

tx_opt_print_plan() {
    local k
    for k in "${TX_OPT_ORDER[@]}"; do
        printf '%s=%s\n' "$k" "${TX_PLAN[$k]}"
    done
}

tx_opt_help() {
    local k spec type allowed def
    for k in "${TX_OPT_ORDER[@]}"; do
        spec="${TX_OPT_SPEC[$k]}"
        type="${spec%%|*}"; allowed="${spec#*|}"; allowed="${allowed%|*}"; def="${spec##*|}"
        case "$type" in
            bool)   printf '  --%-10s %s\n' "$k" "(flag)" ;;
            int)    printf '  --%-10s %s (default: %s)\n' "$k" "number $allowed" "$def" ;;
            list)   printf '  --%-10s %s\n' "$k" "comma-separated Termux package names" ;;
            *)      printf '  --%-10s %s (default: %s)\n' "$k" "${allowed// /|}" "${def:-none}" ;;
        esac
    done
}
