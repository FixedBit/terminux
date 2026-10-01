#!/usr/bin/env bats
# lib/env.sh: named proot environments (terminux env).

load helpers

PD="$BATS_TEST_TMPDIR/usr/var/lib/proot-distro"

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    # proot-distro v4: install [-n NAME] IMAGE creates containers/<name>/rootfs
    stub proot-distro 'printf "proot-distro" >> "$CALLS"; for a in "$@"; do printf "|%s" "${a//$'"'"'\n'"'"'/ }" >> "$CALLS"; done; echo >> "$CALLS"
        pd="'"$PD"'"
        case "$1" in
          install) name=""; img=""; shift
                   while [ $# -gt 0 ]; do case "$1" in -n|--name) name="$2"; shift 2;; *) img="$1"; shift;; esac; done
                   mkdir -p "$pd/containers/${name:-${img%%:*}}/rootfs/etc" ;;
          remove)  rm -rf "$pd/containers/$2" "$pd/installed-rootfs/$2" ;;
          rename)  mv "$pd/containers/$2" "$pd/containers/$3" ;;
        esac; exit 0'
}

@test "list shows nothing to start with, and how to make one" {
    run bash "$TX" env list
    [ "$status" -eq 0 ]
    [[ "$output" == *"terminux env create"* ]]
}

@test "list finds environments in both proot-distro layouts" {
    mkdir -p "$PD/containers/dev/rootfs" "$PD/installed-rootfs/debian"
    run bash "$TX" env list
    [[ "$output" == *"dev"* ]]
    [[ "$output" == *"debian"* ]]
}

@test "create from a profile installs its image under the chosen name" {
    run bash "$TX" env create work --from dev
    [ "$status" -eq 0 ]
    grep -q "^proot-distro|install|--name|work|debian" "$CALLS"
    [ -d "$PD/containers/work/rootfs" ]
}

@test "create runs the profile's setup and records the profile" {
    bash "$TX" env create work --from dev
    grep -q "^proot-distro|login|work|.*apt-get install -y .*build-essential" "$CALLS"
    grep -qx "profile=dev" "$HOME/.config/terminux/envs/work"
}

@test "create refuses a name that's taken or invalid" {
    mkdir -p "$PD/containers/work/rootfs"
    run bash "$TX" env create work --from dev
    [ "$status" -ne 0 ]
    run bash "$TX" env create "Bad Name" --from dev
    [ "$status" -ne 0 ]
}

@test "create with an unknown profile lists the profiles" {
    run bash "$TX" env create x --from nope
    [ "$status" -ne 0 ]
    [[ "$output" == *"dev"* && "$output" == *"minimal"* ]]
}

@test "enter logs in as your user with the display shared" {
    mkdir -p "$PD/containers/work/rootfs" "$HOME/.config/terminux"
    echo user=jason > "$HOME/.config/terminux/config"
    bash "$TX" env enter work
    grep -qx "proot-distro|login|work|--user|jason|--shared-tmp" "$CALLS"
}

@test "run executes one command in an environment" {
    mkdir -p "$PD/containers/work/rootfs"
    bash "$TX" env run work -- uname -a
    grep -q "^proot-distro|login|work|.*|--|uname|-a" "$CALLS"
}

@test "remove asks first, and only deletes when you say yes" {
    mkdir -p "$PD/containers/work/rootfs"
    printf 'n\n' | TERMINUX_TTY=1 bash "$TX" env remove work
    [ -d "$PD/containers/work/rootfs" ]
    printf 'yes\n' | TERMINUX_TTY=1 bash "$TX" env remove work
    [ ! -d "$PD/containers/work" ]
}

@test "remove --yes skips the question" {
    mkdir -p "$PD/containers/work/rootfs"
    bash "$TX" env remove work --yes
    [ ! -d "$PD/containers/work" ]
}

@test "rename moves the environment and its settings" {
    mkdir -p "$PD/containers/work/rootfs" "$HOME/.config/terminux/envs"
    echo profile=dev > "$HOME/.config/terminux/envs/work"
    bash "$TX" env rename work play
    [ -d "$PD/containers/play/rootfs" ]
    grep -qx "profile=dev" "$HOME/.config/terminux/envs/play"
}

@test "plain terminux env lets you pick one and an action" {
    mkdir -p "$PD/containers/work/rootfs"
    # pick env 1, action "run a command" is not interactive here; choose "enter"
    TERMINUX_TTY=1 run bash "$TX" env <<<$'1\n1\n'
    grep -q "^proot-distro|login|work" "$CALLS"
}

@test "profiles list describes each one" {
    run bash "$TX" env profiles
    [ "$status" -eq 0 ]
    for p in dev desktop minimal; do
        [[ "$output" == *"$p"* ]] || { echo "missing profile $p"; return 1; }
    done
}
