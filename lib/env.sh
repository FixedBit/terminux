# shellcheck shell=bash
# terminux -- named proot environments: terminux env.
# Profiles (what an environment starts with) live in envs/<profile>.env.
# SPDX-License-Identifier: Apache-2.0

# shellcheck source=lib/status.sh
. "$TX_LIB/status.sh"

TX_PROFILES_DIR="$TX_LIB/../envs"
TX_ENVS_CFG="$TERMINUX_CONFIG_DIR/envs"
TX_ENV_NAME_RE='^[a-z0-9][a-z0-9_-]{0,31}$'

# Rootfs of an environment. proot-distro v4 uses containers/<name>/rootfs,
# older versions installed-rootfs/<name>.
tx_env_rootfs() {
    local d
    for d in "$TX_PD_DIR/containers/$1/rootfs" "$TX_PD_DIR/installed-rootfs/$1"; do
        [ -d "$d" ] && { echo "$d"; return 0; }
    done
    return 1
}

tx_env_exists() { tx_env_rootfs "$1" >/dev/null; }

tx_env_names() {
    {
        find "$TX_PD_DIR/containers" -mindepth 2 -maxdepth 2 -name rootfs -type d 2>/dev/null \
            | sed 's|/rootfs$||; s|.*/||'
        find "$TX_PD_DIR/installed-rootfs" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sed 's|.*/||'
    } | sort -u
}

_tx_profile_get() { tx_kv_get "$TX_PROFILES_DIR/$1.env" "$2"; }

_tx_env_cmd_profiles() {
    local f p
    for f in "$TX_PROFILES_DIR"/*.env; do
        p=$(basename "$f" .env)
        printf '  %s%-9s%s %s\n' "$TX_W" "$p" "$TX_C0" "$(_tx_profile_get "$p" DESCRIPTION)"
    done
}

_tx_env_cmd_list() {
    local -a names
    mapfile -t names < <(tx_env_names)
    if [ ${#names[@]} -eq 0 ]; then
        echo "No environments yet. Make one with: terminux env create <name> --from <profile>"
        echo "Profiles:"
        _tx_env_cmd_profiles
        return 0
    fi
    local n profile size
    for n in "${names[@]}"; do
        profile=$(tx_kv_get "$TX_ENVS_CFG/$n" profile 2>/dev/null || echo "-")
        size=$(du -sh "$(tx_env_rootfs "$n")" 2>/dev/null | cut -f1)
        printf '  %s%-14s%s profile %-9s %s\n' "$TX_W" "$n" "$TX_C0" "$profile" "${size:-?}"
    done
}

# Root commands that create the user with passwordless sudo.
_tx_env_user_script() {
    local family="$1" user="$2"
    case "$family" in
        apk) echo "id -u $user >/dev/null 2>&1 || adduser -D -s /bin/bash $user; addgroup $user wheel 2>/dev/null; mkdir -p /etc/sudoers.d; echo '$user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$user" ;;
        *)   echo "id -u $user >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo $user; echo '$user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/$user; chmod 0440 /etc/sudoers.d/$user" ;;
    esac
}

_tx_env_cmd_create() {
    local name="${1:-}" profile=dev
    shift || true
    while [ $# -gt 0 ]; do
        case "$1" in
            --from) profile="${2:-}"; shift 2 ;;
            *) tx_fail "unknown option: $1"; return 2 ;;
        esac
    done
    [[ "$name" =~ $TX_ENV_NAME_RE ]] || { tx_fail "'$name' isn't a valid name (lowercase letters, digits, - and _)"; return 2; }
    tx_env_exists "$name" && { tx_fail "An environment called '$name' already exists."; return 1; }
    if [ ! -f "$TX_PROFILES_DIR/$profile.env" ]; then
        tx_fail "No profile called '$profile'. These are available:"
        _tx_env_cmd_profiles
        return 2
    fi

    local image family packages user
    image=$(_tx_profile_get "$profile" IMAGE)
    family=$(_tx_profile_get "$profile" FAMILY)
    packages=$(_tx_profile_get "$profile" PACKAGES)
    user=$(tx_debian_user)

    tx_has proot-distro || pkg install -y proot-distro || return 1
    tx_step "Creating '$name' from the $profile profile ($image)"
    proot-distro install --name "$name" "$image" || { tx_fail "proot-distro couldn't install $image"; return 1; }

    local setup
    case "$family" in
        apk) setup="apk update && apk add $packages" ;;
        *)   setup="export DEBIAN_FRONTEND=noninteractive; apt-get update -q && apt-get install -y sudo $packages" ;;
    esac
    setup+="; $(_tx_env_user_script "$family" "$user")"
    proot-distro login "$name" --shared-tmp -- sh -c "$setup" \
        || tx_warn "Some of the $profile setup failed; the environment is there, fix it with: terminux env enter $name"

    local root; root=$(tx_env_rootfs "$name")
    mkdir -p "$root/etc/profile.d"
    printf '# Written by terminux.\nexport DISPLAY=:0\nexport PULSE_SERVER=127.0.0.1\n' > "$root/etc/profile.d/terminux.sh"

    mkdir -p "$TX_ENVS_CFG"
    printf 'profile=%s\nimage=%s\n' "$profile" "$image" > "$TX_ENVS_CFG/$name"
    tx_ok "'$name' is ready. Enter it with: terminux env enter $name"
}

_tx_env_need() {
    [ -n "${1:-}" ] || { tx_fail "Which environment? See: terminux env list"; return 2; }
    tx_env_exists "$1" || { tx_fail "No environment called '$1'. See: terminux env list"; return 1; }
}

_tx_env_cmd_enter() {
    _tx_env_need "${1:-}" || return
    proot-distro login "$1" --user "$(tx_debian_user)" --shared-tmp
}

_tx_env_cmd_run() {
    _tx_env_need "${1:-}" || return
    local name="$1"; shift
    [ "${1:-}" = -- ] && shift
    proot-distro login "$name" --user "$(tx_debian_user)" --shared-tmp -- "$@"
}

_tx_confirm() {
    local answer
    read -rp "$1 [y/N] " answer || return 1
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

_tx_env_cmd_remove() {
    _tx_env_need "${1:-}" || return
    local name="$1"
    if [ "${2:-}" != --yes ]; then
        _tx_confirm "Delete '$name' and everything in it?" || { tx_info "Kept '$name'."; return 0; }
    fi
    proot-distro remove "$name" && rm -f "$TX_ENVS_CFG/$name"
    tx_ok "Removed '$name'."
}

_tx_env_cmd_rename() {
    _tx_env_need "${1:-}" || return
    [[ "${2:-}" =~ $TX_ENV_NAME_RE ]] || { tx_fail "'${2:-}' isn't a valid name"; return 2; }
    proot-distro rename "$1" "$2" || return 1
    [ -f "$TX_ENVS_CFG/$1" ] && mv "$TX_ENVS_CFG/$1" "$TX_ENVS_CFG/$2"
    tx_ok "Renamed '$1' to '$2'."
}

_tx_env_cmd_backup() {
    _tx_env_need "${1:-}" || return
    local out="${2:-$HOME/$1-$(date +%Y%m%d).tar.gz}"
    proot-distro backup "$1" --output "$out" && tx_ok "Saved to $out"
}

_tx_env_cmd_reset() {
    _tx_env_need "${1:-}" || return
    _tx_confirm "Reset '$1' to a fresh install (everything in it is lost)?" || return 0
    proot-distro reset "$1"
}

# Plain `terminux env`: pick an environment, then what to do with it.
_tx_env_pick() {
    local -a names
    mapfile -t names < <(tx_env_names)
    [ ${#names[@]} -gt 0 ] || { _tx_env_cmd_list; return 0; }
    local i=1 n choice
    echo
    for n in "${names[@]}"; do printf '  %s%2d%s  %s\n' "$TX_B" "$i" "$TX_C0" "$n"; i=$((i + 1)); done
    read -rp "  Environment: " choice || return 0
    [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#names[@]}" ] \
        || { tx_warn "No such environment."; return 2; }
    n="${names[$((choice - 1))]}"
    printf '\n  1  Enter\n  2  Run a command\n  3  Rename\n  4  Back up\n  5  Reset\n  6  Remove\n'
    read -rp "  Do: " choice || return 0
    case "$choice" in
        1) _tx_env_cmd_enter "$n" ;;
        2) local c; read -rp "  Command: " c && _tx_env_cmd_run "$n" -- sh -c "$c" ;;
        3) local new; read -rp "  New name: " new && _tx_env_cmd_rename "$n" "$new" ;;
        4) _tx_env_cmd_backup "$n" ;;
        5) _tx_env_cmd_reset "$n" ;;
        6) _tx_env_cmd_remove "$n" ;;
        *) tx_warn "No such action." ;;
    esac
}

cmd_env() {
    local sub="${1:-}"
    [ $# -gt 0 ] && shift
    case "$sub" in
        "")
            if [ -t 0 ] || [ "${TERMINUX_TTY:-0}" = 1 ]; then _tx_env_pick; else _tx_env_cmd_list; fi ;;
        list|ls)      _tx_env_cmd_list ;;
        profiles)     _tx_env_cmd_profiles ;;
        create|new)   _tx_env_cmd_create "$@" ;;
        enter|login)  _tx_env_cmd_enter "$@" ;;
        run)          _tx_env_cmd_run "$@" ;;
        remove|rm)    _tx_env_cmd_remove "$@" ;;
        rename|mv)    _tx_env_cmd_rename "$@" ;;
        backup)       _tx_env_cmd_backup "$@" ;;
        reset)        _tx_env_cmd_reset "$@" ;;
        *) tx_fail "usage: terminux env [list|profiles|create|enter|run|rename|backup|reset|remove]"; return 2 ;;
    esac
}
