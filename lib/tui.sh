# shellcheck shell=bash
# terminux -- the terminal wizard: what install.sh runs when you give it no
# options. Same steps, rules and wording as the web wizard; it all comes from
# options.json through lib/options.gen.sh.
# SPDX-License-Identifier: Apache-2.0

# Drop list items that no longer apply after an earlier answer changed.
_tui_settle() {
    local k item kept
    local -a items
    for k in "${TX_OPT_ORDER[@]}"; do
        [ "$(_tx_spec_part "$k" type)" = multi ] || continue
        kept=""
        IFS=',' read -ra items <<< "${TX_PLAN[$k]}"
        for item in "${items[@]}"; do
            [ -n "$item" ] && tx_choice_applies "$k" "$item" && kept+="${kept:+,}$item"
        done
        TX_PLAN[$k]="$kept"
    done
}

_tui_read() {  # <prompt> -> $REPLY ("b" means back)
    printf '%s' "$1"
    IFS= read -r REPLY || REPLY=""
    # A keyboard echoes Enter; piped answers don't, so end the line ourselves.
    [ -t 0 ] || echo
    REPLY="${REPLY%$'\r'}"
    REPLY="${REPLY#"${REPLY%%[![:space:]]*}"}"; REPLY="${REPLY%"${REPLY##*[![:space:]]}"}"
}

_tui_help() { [ -n "$1" ] && printf '     %s%s%s\n' "$TX_D" "$1" "$TX_C0"; return 0; }

# Each _tui_ask_* returns 1 when the user typed b (back).
_tui_ask_choice() {
    local k="$1" i=1 v cur="${TX_PLAN[$1]}"
    local -a vals=()
    printf '\n  %s%s%s\n' "$TX_W" "${TX_OPT_LABEL[$k]}" "$TX_C0"
    for v in $(_tx_spec_part "$k" allowed); do
        tx_choice_applies "$k" "$v" || continue
        vals+=("$v")
        printf '  %s%2d)%s %s%s\n' "$TX_B" "$i" "$TX_C0" "${TX_CHOICE_LABEL[$k:$v]}" "$([ "$v" = "$cur" ] && echo "  (current)")"
        _tui_help "${TX_CHOICE_HELP[$k:$v]}"
        i=$((i + 1))
    done
    while true; do
        _tui_read "  Choose 1-${#vals[@]}, Enter keeps current, b goes back: "
        case "$REPLY" in
            b|B) return 1 ;;
            "") return 0 ;;
        esac
        if [[ "$REPLY" =~ ^[0-9]+$ ]] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#vals[@]}" ]; then
            TX_PLAN[$k]="${vals[$((REPLY - 1))]}"
            return 0
        fi
        tx_warn "'$REPLY' isn't one of the numbers."
    done
}

_tui_ask_multi() {
    local k="$1" v n cat="" shown
    local -a vals=()
    for v in $(_tx_spec_part "$k" allowed); do
        tx_choice_applies "$k" "$v" && vals+=("$v")
    done
    [ ${#vals[@]} -gt 0 ] || return 0
    while true; do
        printf '\n  %s%s%s\n' "$TX_W" "${TX_OPT_LABEL[$k]}" "$TX_C0"
        _tui_help "${TX_OPT_HELP[$k]}"
        cat=""
        for n in "${!vals[@]}"; do
            v="${vals[$n]}"
            if [ -n "${TX_CHOICE_CATEGORY[$k:$v]:-}" ] && [ "${TX_CHOICE_CATEGORY[$k:$v]}" != "$cat" ]; then
                cat="${TX_CHOICE_CATEGORY[$k:$v]}"
                printf '   %s%s%s\n' "$TX_D" "${TX_CATEGORY_TITLE[$cat]:-$cat}" "$TX_C0"
            fi
            if [[ ",${TX_PLAN[$k]}," == *",$v,"* ]]; then shown="[x]"; else shown="[ ]"; fi
            printf '  %s%2d)%s %s %s\n' "$TX_B" "$((n + 1))" "$TX_C0" "$shown" "${TX_CHOICE_LABEL[$k:$v]}"
        done
        _tui_read "  Numbers toggle (e.g. 2 5), a all, n none, Enter when done, b back: "
        case "$REPLY" in
            b|B) return 1 ;;
            "") return 0 ;;
            a|A) TX_PLAN[$k]=$(IFS=,; echo "${vals[*]}"); continue ;;
            n|N) TX_PLAN[$k]=""; continue ;;
        esac
        for n in $REPLY; do
            if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#vals[@]}" ]; then
                v="${vals[$((n - 1))]}"
                if [[ ",${TX_PLAN[$k]}," == *",$v,"* ]]; then
                    TX_PLAN[$k]=$(tr ',' '\n' <<< "${TX_PLAN[$k]}" | grep -vx "$v" | paste -sd, -)
                else
                    TX_PLAN[$k]="${TX_PLAN[$k]:+${TX_PLAN[$k]},}$v"
                fi
            else
                tx_warn "'$n' isn't one of the numbers."
            fi
        done
        # Keep the schema's order.
        local ordered=""
        for v in "${vals[@]}"; do
            [[ ",${TX_PLAN[$k]}," == *",$v,"* ]] && ordered+="${ordered:+,}$v"
        done
        TX_PLAN[$k]="$ordered"
    done
}

_tui_ask_bool() {
    local k="$1" cur="${TX_PLAN[$1]}" hint
    [ "$cur" = yes ] && hint="Y/n" || hint="y/N"
    printf '\n'
    _tui_help "${TX_OPT_HELP[$k]}"
    while true; do
        _tui_read "  ${TX_OPT_LABEL[$k]}? [$hint, b back] "
        case "$REPLY" in
            b|B) return 1 ;;
            "") return 0 ;;
            y|Y|yes) TX_PLAN[$k]=yes; return 0 ;;
            n|N|no) TX_PLAN[$k]=no; return 0 ;;
        esac
        tx_warn "Answer y or n."
    done
}

_tui_ask_text() {
    local k="$1" type cur="${TX_PLAN[$1]}" shown
    type=$(_tx_spec_part "$k" type)
    shown="$cur"
    [ "$type" = int ] && [ "$cur" = auto ] && shown="automatic"
    printf '\n'
    _tui_help "${TX_OPT_HELP[$k]}"
    while true; do
        _tui_read "  ${TX_OPT_LABEL[$k]} [${shown:-none}], b back: "
        case "$REPLY" in
            b|B) return 1 ;;
            "") return 0 ;;
        esac
        if tx_opt_set "$k" "$REPLY" 2>/dev/null; then
            unset 'TX_SET[$k]'
            return 0
        fi
        case "$type" in
            text) tx_warn "'$REPLY' isn't a valid name. Lowercase letters, digits, - and _, starting with a letter." ;;
            int)  tx_warn "'$REPLY' isn't a number in range." ;;
            *)    tx_warn "'$REPLY' isn't a list of package names." ;;
        esac
    done
}

_tui_step() {  # <group> -> 1 if the user went back
    local g="$1" k
    for k in "${TX_OPT_ORDER[@]}"; do
        [ "${TX_OPT_GROUP[$k]}" = "$g" ] || continue
        _tui_settle
        tx_opt_applies "$k" || continue
        case "$(_tx_spec_part "$k" type)" in
            choice) _tui_ask_choice "$k" || return 1 ;;
            multi)  _tui_ask_multi "$k" || return 1 ;;
            bool)   _tui_ask_bool "$k" || return 1 ;;
            *)      _tui_ask_text "$k" || return 1 ;;
        esac
    done
    _tui_settle
}

# The equivalent non-interactive command, to repeat this setup later.
tx_tui_command() {
    local k type v def args="" item kept
    local -a items
    for k in "${TX_OPT_ORDER[@]}"; do
        tx_opt_applies "$k" || continue
        type=$(_tx_spec_part "$k" type); v="${TX_PLAN[$k]}"; def=$(_tx_spec_part "$k" default)
        if [ "$type" = multi ]; then
            kept=""
            IFS=',' read -ra items <<< "$def"
            for item in "${items[@]}"; do tx_choice_applies "$k" "$item" && kept+="${kept:+,}$item"; done
            def="$kept"
        fi
        [ "$v" = "$def" ] && continue
        case "$type" in
            bool) if [ "$v" = yes ]; then args+=" --$k"; else args+=" --no-$k"; fi ;;
            multi) args+=" --$k ${v:-none}" ;;
            *) args+=" --$k $v" ;;
        esac
    done
    echo "bash install.sh${args} --yes"
}

_tui_review() {
    local k label v
    printf '\n%s==>%s %sReview%s\n\n' "$TX_B" "$TX_C0" "$TX_W" "$TX_C0"
    for k in "${TX_OPT_ORDER[@]}"; do
        tx_opt_applies "$k" || continue
        v="${TX_PLAN[$k]}"
        case "$(_tx_spec_part "$k" type)" in
            choice) v="${TX_CHOICE_LABEL[$k:$v]:-$v}" ;;
            multi)
                local out="" item
                for item in ${v//,/ }; do out+="${out:+, }${TX_CHOICE_LABEL[$k:$item]:-$item}"; done
                v="${out:-none}" ;;
            int) [ "$v" = auto ] && v="automatic" ;;
        esac
        label="${TX_OPT_LABEL[$k]}"
        printf '  %-26s %s\n' "${label:0:26}" "${v:-none}"
    done
    printf '\n  Same setup later, without the questions:\n    %s\n\n' "$(tx_tui_command)"
}

# Walk through every step; returns 1 if the user decides not to install.
tx_tui_run() {
    local i=0 n=${#TX_GROUPS[@]} g
    printf '\n%sterminux setup%s  Answer a few questions, or press Enter to keep the suggestion.\n' "$TX_W" "$TX_C0"
    while [ "$i" -lt "$n" ]; do
        g="${TX_GROUPS[$i]}"
        printf '\n%s==>%s %sStep %d of %d: %s%s  %s%s%s\n' "$TX_B" "$TX_C0" "$TX_W" $((i + 1)) "$n" \
            "${TX_GROUP_TITLE[$g]}" "$TX_C0" "$TX_D" "${TX_GROUP_INTRO[$g]}" "$TX_C0"
        if _tui_step "$g"; then
            i=$((i + 1))
        else
            [ "$i" -gt 0 ] && i=$((i - 1))
        fi
    done
    _tui_review
    _tui_read "  Install now? [Y/n] "
    case "$REPLY" in
        n|N|no) echo "  Nothing was installed. Run the installer again any time."; return 1 ;;
    esac
}
