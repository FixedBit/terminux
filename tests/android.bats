#!/usr/bin/env bats
# lib/android.sh: making sure the Termux:X11 and Termux:API apps are there.

load helpers

setup() {
    tx_sandbox
    export CALLS="$BATS_TEST_TMPDIR/calls.log"; : > "$CALLS"
    stub termux-open 'echo "termux-open $*" >> "$CALLS"'
    stub termux-open-url 'echo "termux-open-url $*" >> "$CALLS"'
    stub curl 'echo "curl $*" >> "$CALLS"
        case "$*" in *api.github.com*termux-api*) echo "\"browser_download_url\": \"https://github.com/termux/termux-api/releases/download/v0.53.0/termux-api-app_v0.53.0%2Bgithub.debug.apk\"";; esac
        while [ $# -gt 0 ]; do [ "$1" = -o ] && echo apk > "$2"; shift; done'
    tx_load android
}

installed() { stub pm "echo 'package:$*' | tr ' ' '\n' | sed 's/^/package:/' ; exit 0"; }

@test "nothing happens when both apps are installed" {
    stub pm 'printf "package:com.termux.x11\npackage:com.termux.api\n"'
    tx_android_ensure_apps </dev/null
    run grep -c termux-open "$CALLS"
    [ "$output" = 0 ]
}

@test "a missing Termux:X11 is downloaded from its nightly release and opened" {
    stub pm 'printf "package:com.termux.api\n"'
    tx_android_ensure_apps </dev/null
    grep -q "curl .*github.com/termux/termux-x11/releases/download/nightly/termux-x11-universal-debug.apk" "$CALLS"
    grep -q "termux-open .*application/vnd.android.package-archive" "$CALLS"
}

@test "Termux:API comes from F-Droid when Termux did (signatures must match)" {
    stub pm 'printf "package:com.termux.x11\n"'
    TERMUX_APK_RELEASE=F_DROID tx_android_ensure_apps </dev/null
    grep -q "termux-open-url https://f-droid.org/packages/com.termux.api/" "$CALLS"
}

@test "Termux:API comes from GitHub when Termux did" {
    stub pm 'printf "package:com.termux.x11\n"'
    TERMUX_APK_RELEASE=GITHUB tx_android_ensure_apps </dev/null
    grep -q "curl .*termux-api-app_v0.53.0" "$CALLS"
    grep -q "termux-open .*package-archive" "$CALLS"
}

@test "when Android won't say what's installed, it doesn't guess" {
    stub pm 'exit 1'
    run tx_android_ensure_apps </dev/null
    [ "$status" -eq 0 ]
    [[ "$output" == *"Termux:X11"* ]]
    run grep -c termux-open "$CALLS"
    [ "$output" = 0 ]
}
