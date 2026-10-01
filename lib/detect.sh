# shellcheck shell=bash
# =============================================================================
#  terminux -- device detection.
#
#  Adapted from ternux lib/detect.sh (https://github.com/soobujmiah/ternux,
#  Apache-2.0, (c) 2026 Sobuj Miah); modified for terminux. See NOTICE.
# =============================================================================

tx_detect_model()   { tx_getprop ro.product.model; }
tx_detect_android() { tx_getprop ro.build.version.release; }
tx_detect_sdk()     { local s; s=$(tx_getprop ro.build.version.sdk); echo "${s:-0}"; }

# Galaxy Z Fold models are SM-F9xx (the Flip line is SM-F7xx).
tx_is_fold() { case "$(tx_detect_model)" in SM-F9*) return 0 ;; esac; return 1; }

tx_detect_ram_gb() {
    awk '/MemTotal/ { printf "%d", ($2 / 1048576) + 0.5 }' /proc/meminfo 2>/dev/null || echo "?"
}

tx_detect_swap_free_mb() {
    awk '/SwapFree/ { printf "%d", $2 / 1024 }' /proc/meminfo 2>/dev/null || echo "?"
}

tx_detect_storage_gb() {
    df -Pk "${1:-$HOME}" 2>/dev/null | awk 'NR == 2 { print int($4 / 1048576) }'
}

tx_detect_gpu() {
    if [ -e /dev/kgsl-3d0 ]; then
        local model
        model=$(cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null || true)
        echo "Adreno${model:+ ($model)}"
    elif grep -qi mali /proc/cpuinfo 2>/dev/null; then
        echo "Mali"
    else
        local egl; egl=$(tx_getprop ro.hardware.egl)
        echo "${egl:-unknown}"
    fi
}

# Which Vulkan device Mesa actually picked: turnip | software | none | unknown
tx_detect_vulkan_driver() {
    tx_has vulkaninfo || { echo unknown; return; }
    local out
    out=$(vulkaninfo --summary 2>/dev/null) || { echo none; return; }
    if grep -qiE "turnip|adreno" <<<"$out"; then echo turnip
    elif grep -qiE "llvmpipe|lavapipe" <<<"$out"; then echo software
    else echo unknown
    fi
}

# Android 12+ "phantom process" monitor: enabled | disabled | n/a | unknown.
# Apps usually may read global settings; if not, report unknown rather than guess.
tx_detect_phantom_killer() {
    [ "$(tx_detect_sdk)" -lt 31 ] 2>/dev/null && { echo "n/a"; return; }
    case "$(settings get global settings_enable_monitor_phantom_procs 2>/dev/null)" in
        0|false) echo disabled ;;
        1|true)  echo enabled ;;
        *)       echo unknown ;;
    esac
}
