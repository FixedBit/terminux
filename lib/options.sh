# shellcheck shell=bash
# terminux -- install options: parsing, validation and the "when" rules.
# SPDX-License-Identifier: Apache-2.0
#
# The schema itself comes from options.json via lib/options.gen.sh (a fresh
# phone has no jq). The rule logic here mirrors applyRules in
# site/assets/command.js; tests/options.bats checks they agree.

# shellcheck source=lib/options.gen.sh
. "$TX_LIB/options.gen.sh"

TX_PKG_NAME_RE='^[a-z0-9][a-z0-9+._-]*$'

declare -gA TX_PLAN=()
declare -gA TX_SET=()     # options given explicitly on the command line

_tx_spec_part() {  # <id> type|allowed|default
    local spec="${TX_OPT_SPEC[$1]}"
    case "$2" in
        type)    echo "${spec%%|*}" ;;
        allowed) spec="${spec#*|}"; echo "${spec%|*}" ;;
        default) echo "${spec##*|}" ;;
    esac
}

tx_opt_defaults() {
    local k
    for k in "${TX_OPT_ORDER[@]}"; do
        TX_PLAN[$k]="$(_tx_spec_part "$k" default)"
    done
}

_tx_opt_bad() { tx_fail "$1"; return 2; }

# --- rules -----------------------------------------------------------------

# One alternative, e.g. "base=termux&de=xfce,lxqt" or "envs=*".
_tx_alt_ok() {
    local cond k want have v
    local -a conds _have
    IFS='&' read -ra conds <<< "$1"
    for cond in "${conds[@]}"; do
        k="${cond%%=*}"; want="${cond#*=}"; have="${TX_PLAN[$k]:-}"
        if [ "$want" = "*" ]; then
            [ -n "$have" ] || return 1
            continue
        fi
        local hit=0
        IFS=',' read -ra _have <<< "$have"
        for v in "${_have[@]}"; do
            [[ ",$want," == *",$v,"* ]] && { hit=1; break; }
        done
        [ "$hit" = 1 ] || return 1
    done
}

_tx_when_ok() {
    local expr="$1" alt
    [ -n "$expr" ] || return 0
    local -a alts
    IFS=';' read -ra alts <<< "$expr"
    for alt in "${alts[@]}"; do _tx_alt_ok "$alt" && return 0; done
    return 1
}

tx_opt_applies()    { _tx_when_ok "${TX_OPT_WHEN[$1]:-}"; }
tx_choice_applies() { _tx_when_ok "${TX_CHOICE_WHEN[$1:$2]:-}"; }

# "base=termux&de=xfce,lxqt;envs=*" -> words for error messages.
tx_when_describe() {
    local expr="$1" out="" alt cond k v
    local -a alts conds parts
    IFS=';' read -ra alts <<< "$expr"
    for alt in "${alts[@]}"; do
        parts=()
        IFS='&' read -ra conds <<< "$alt"
        for cond in "${conds[@]}"; do
            k="${cond%%=*}"; v="${cond#*=}"
            if [ "$v" = "*" ]; then parts+=("--$k is set")
            else parts+=("--$k is ${v//,/ or }"); fi
        done
        local joined; joined=$(printf '%s and ' "${parts[@]}"); joined="${joined% and }"
        out+="${out:+, or }$joined"
    done
    echo "$out"
}

# Apply the rules after parsing: drop what doesn't apply, and refuse it when
# it was asked for explicitly.
tx_opt_apply_rules() {
    local k type v item kept
    local -a items
    # Apps that need glibc run in the Debian environment, when there is one
    # to add (on a Debian base you're already in it).
    v="${TX_PLAN[with]:-}"
    if [[ ",$v," =~ ,(vscode-ms|cursor), ]] && [[ ",$v," != *,debian,* ]] \
        && tx_choice_applies with debian; then
        TX_PLAN[with]="debian${v:+,$v}"
    fi
    # Pass 1: choices inside lists and single choices.
    for k in "${TX_OPT_ORDER[@]}"; do
        type=$(_tx_spec_part "$k" type)
        case "$type" in
            multi)
                kept=""
                IFS=',' read -ra items <<< "${TX_PLAN[$k]}"
                for item in "${items[@]}"; do
                    [ -n "$item" ] || continue
                    if tx_choice_applies "$k" "$item"; then
                        kept+="${kept:+,}$item"
                    elif [ -n "${TX_SET[$k]:-}" ]; then
                        _tx_opt_bad "--$k $item only applies when $(tx_when_describe "${TX_CHOICE_WHEN[$k:$item]}")"
                        return 2
                    fi
                done
                TX_PLAN[$k]="$kept" ;;
            choice)
                v="${TX_PLAN[$k]}"
                if [ -n "$v" ] && ! tx_choice_applies "$k" "$v"; then
                    _tx_opt_bad "--$k $v only applies when $(tx_when_describe "${TX_CHOICE_WHEN[$k:$v]}")"
                    return 2
                fi ;;
        esac
    done
    # Pass 2: whole options.
    for k in "${TX_OPT_ORDER[@]}"; do
        tx_opt_applies "$k" && continue
        if [ -n "${TX_SET[$k]:-}" ]; then
            _tx_opt_bad "--$k only applies when $(tx_when_describe "${TX_OPT_WHEN[$k]}")"
            return 2
        fi
        TX_PLAN[$k]=""
    done
}

# --- parsing ---------------------------------------------------------------

# Validate and store one option. Returns 2 on invalid input.
tx_opt_set() {
    local key="$1" value="$2" type allowed item
    [ -n "${TX_OPT_SPEC[$key]:-}" ] || { _tx_opt_bad "unknown option: --$key"; return 2; }
    type=$(_tx_spec_part "$key" type)
    allowed=$(_tx_spec_part "$key" allowed)
    TX_SET[$key]=1

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
tx_opt_is_bool() { [ "$(_tx_spec_part "$1" type)" = bool ]; }

tx_opt_print_plan() {
    local k
    for k in "${TX_OPT_ORDER[@]}"; do
        printf '%s=%s\n' "$k" "${TX_PLAN[$k]}"
    done
}

tx_opt_help() {
    local k type allowed def
    for k in "${TX_OPT_ORDER[@]}"; do
        type=$(_tx_spec_part "$k" type)
        allowed=$(_tx_spec_part "$k" allowed)
        def=$(_tx_spec_part "$k" default)
        case "$type" in
            bool)
                if [ "$def" = yes ]; then printf '  --%-10s %s\n' "$k" "on by default; --no-$k turns it off"
                else printf '  --%-10s %s\n' "$k" "(flag)"; fi ;;
            text)   printf '  --%-10s %s (default: %s)\n' "$k" "name" "$def" ;;
            int)    printf '  --%-10s %s (default: %s)\n' "$k" "number $allowed" "$def" ;;
            list)   printf '  --%-10s %s\n' "$k" "comma-separated package names" ;;
            *)      printf '  --%-10s %s (default: %s)\n' "$k" "${allowed// /|}" "${def:-none}" ;;
        esac
    done
}
