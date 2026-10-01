# shellcheck shell=bash
# terminux -- `terminux info`: device and GPU profile.

# shellcheck source=lib/detect.sh
. "$TX_LIB/detect.sh"

cmd_info() {
    local row='  %-16s %s\n'
    printf "$row" "Model:"    "$(tx_detect_model) $(tx_is_fold && echo '(Galaxy Fold)')"
    printf "$row" "Android:"  "$(tx_detect_android) (SDK $(tx_detect_sdk))"
    printf "$row" "Arch:"     "$(uname -m)"
    printf "$row" "RAM:"      "$(tx_detect_ram_gb) GB, swap free $(tx_detect_swap_free_mb) MB"
    printf "$row" "Storage:"  "$(tx_detect_storage_gb) GB free"
    printf "$row" "GPU:"      "$(tx_detect_gpu)"
    printf "$row" "Vulkan:"   "$(tx_detect_vulkan_driver)"
    printf "$row" "Phantom killer:" "$(tx_detect_phantom_killer)"
    printf "$row" "terminux:" "$TERMINUX_VERSION at $TERMINUX_HOME"
}
