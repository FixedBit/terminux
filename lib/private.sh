# shellcheck shell=bash
# terminux -- private values (NetBird key, server URL, ...) supplied at
# install time. Parsed as KEY=VALUE against an allow-list; never sourced or
# executed. See docs/adr/0003-secrets-at-runtime.md.
# SPDX-License-Identifier: Apache-2.0

TX_PRIVATE_KEY_RE='^(NB|TERMINUX)_[A-Z0-9_]+$'
TX_PRIVATE_DEFAULT="$TERMINUX_CONFIG_DIR/private.env"

# Read KEY=VALUE lines on stdin and export the allowed ones that aren't
# already set in the environment (the environment wins).
_tx_private_parse() {
    local line key value
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        case "$line" in ''|'#'*) continue ;; esac
        line="${line#export }"
        [[ "$line" == *=* ]] || continue
        key="${line%%=*}"
        value="${line#*=}"
        [[ "$key" =~ $TX_PRIVATE_KEY_RE ]] || continue
        if [[ "$value" == \"*\" ]]; then value="${value:1:${#value}-2}"
        elif [[ "$value" == \'*\' ]]; then value="${value:1:${#value}-2}"
        fi
        [ -n "${!key:-}" ] && continue
        printf -v "$key" '%s' "$value"
        export "${key?}"
    done
}

# tx_private_load <file | https://link>
tx_private_load() {
    local src="$1" content
    case "$src" in
        https://*)
            content=$(curl -fsSL "$src") || { tx_fail "couldn't download $src"; return 1; } ;;
        http://*)
            tx_fail "refusing $src: private values must come over https"; return 1 ;;
        *)
            [ -f "$src" ] || { tx_fail "no such file: $src"; return 1; }
            content=$(cat "$src") ;;
    esac
    _tx_private_parse <<< "$content"
}

# ~/.config/terminux/private.env, if present, kept readable by you only.
tx_private_load_default() {
    [ -f "$TX_PRIVATE_DEFAULT" ] || return 0
    chmod 600 "$TX_PRIVATE_DEFAULT" 2>/dev/null
    tx_private_load "$TX_PRIVATE_DEFAULT"
}
