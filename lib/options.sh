# shellcheck shell=bash
# terminux -- install options: parsing and validation for install.sh.
# SPDX-License-Identifier: Apache-2.0
#
# Mirrors options.json in plain bash, because a fresh phone has no jq.
# tests/options.bats fails if the two disagree. See docs/adr/0005.

# flag -> "type|allowed values|default"   (types: choice multi bool int list text)
declare -gA TX_OPT_SPEC=(
    [de]="choice|xfce lxqt mate kde|xfce"
    [wine]="bool||no"
    [theme]="choice|dark light|dark"
    [dpi]="int|72-320|auto"
    [tweaks]="multi|wakelock gpu-check phantom oneui-audio touch hidpi|wakelock,gpu-check,phantom,oneui-audio,touch,hidpi"
    [apps]="multi|vscode firefox chromium vlc gimp libreoffice python nodejs build|vscode,firefox,vlc,python"
    [packages]="list||"
    [with]="multi|debian vscode-ms cursor netbird|"
    [ai]="multi|$(awk -F'\t' '!/^#/ && $2 == "ai" { printf "%s ", $1 }' "$TX_LIB/../catalog.tsv" 2>/dev/null)|"
    [ssh]="bool||no"
    [user]='text|^[a-z_][a-z0-9_-]{0,31}$|user'
    [shell]="choice|zsh bash|zsh"
    [zsh]="multi|ohmyzsh powerlevel10k autosuggestions syntax-highlighting|ohmyzsh,powerlevel10k,autosuggestions,syntax-highlighting"
    [banner]="bool||yes"
)
# Plan output order (matches options.json).
TX_OPT_ORDER=(de wine theme dpi tweaks apps packages with ai ssh user shell zsh banner)

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
            # --no-<flag> arrives here as value "no".
            TX_PLAN[$key]="${value:-yes}" ;;
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
            # Apps that need glibc run in the Debian environment.
            if [ "$key" = with ] && [[ ",$value," =~ ,(vscode-ms|cursor), ]] \
                && [[ ",$value," != *,debian,* ]]; then
                value="debian,$value"
            fi
            TX_PLAN[$key]="$value" ;;
        text)
            [[ "$value" =~ $allowed ]] \
                || { _tx_opt_bad "--$key: '$value' must match $allowed"; return 2; }
            case "$value" in
                root|nobody|daemon|bin|sys)
                    _tx_opt_bad "--$key: '$value' is a system account"; return 2 ;;
            esac
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
            bool)
                if [ "$def" = yes ]; then printf '  --%-10s %s\n' "$k" "on by default; --no-$k turns it off"
                else printf '  --%-10s %s\n' "$k" "(flag)"; fi ;;
            text)   printf '  --%-10s %s (default: %s)\n' "$k" "name" "$def" ;;
            int)    printf '  --%-10s %s (default: %s)\n' "$k" "number $allowed" "$def" ;;
            list)   printf '  --%-10s %s\n' "$k" "comma-separated Termux package names" ;;
            *)      printf '  --%-10s %s (default: %s)\n' "$k" "${allowed// /|}" "${def:-none}" ;;
        esac
    done
}
