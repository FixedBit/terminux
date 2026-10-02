#!/bin/bash
# Every apt package terminux installs inside Debian and Ubuntu exists there
# (needs ptrace for proot: run on a native-arch image).
. /repo/tests/container/lib.sh
prepare proot-distro
# shellcheck disable=SC2034 # read by the sourced modules
TX_LIB=/repo/lib; . /repo/lib/core.sh; . /repo/lib/prootdesk.sh
for base in debian ubuntu; do
    proot-distro install "$base" >/dev/null 2>&1 || { fail "$base installs"; continue; }
    pass "$base installs"
    names="$TX_DISTRO_COMMON_PKGS zsh"
    for de in xfce lxqt mate kde; do names+=" $(tx_distro_de_packages "$de")"; done
    for app in firefox chromium vlc gimp libreoffice python nodejs build; do
        names+=" $(tx_distro_app_packages "$base" "$app")"
    done
    missing=$(proot-distro login "$base" -- bash -c "
        apt-get update -qq >/dev/null 2>&1
        for p in $names; do
            c=\$(apt-cache policy \"\$p\" 2>/dev/null | awk '/Candidate:/ { print \$2 }')
            { [ -z \"\$c\" ] || [ \"\$c\" = '(none)' ]; } && echo \"\$p\"
        done")
    if [ -z "$missing" ]; then pass "$base has all $(wc -w <<<"$names") packages"
    else for p in $missing; do fail "$base has no package $p"; done; fi
done
done_checks
