#!/usr/bin/env bash
# system_info.sh — Hardware detection functions

# ── CPU Info ─────────────────────────────────────────────────────────────────
get_cpu_info() {
    draw_section "CPU"

    local model cores threads freq_mhz freq_ghz cache_l2 cache_l3

    model=$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')
    model=${model:-$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)}
    cores=$(lscpu 2>/dev/null | awk -F: '/^Core\(s\) per socket/ {gsub(/[ \t]/, "", $2); print $2}')
    local sockets
    sockets=$(lscpu 2>/dev/null | awk -F: '/^Socket\(s\)/ {gsub(/[ \t]/, "", $2); print $2}')
    cores=$(( ${cores:-1} * ${sockets:-1} ))
    threads=$(nproc 2>/dev/null || echo "?")

    # Current / max frequencies
    local cur_freq max_freq
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq ]]; then
        cur_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null)
        cur_freq=$(awk "BEGIN {printf \"%.2f\", ${cur_freq}/1000000}")
    fi
    if [[ -r /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq ]]; then
        max_freq=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
        max_freq=$(awk "BEGIN {printf \"%.2f\", ${max_freq}/1000000}")
    fi
    # Fallback to lscpu
    if [[ -z "$max_freq" ]]; then
        max_freq=$(lscpu 2>/dev/null | awk -F: '/CPU max MHz/ {gsub(/[ \t]/, "", $2); printf "%.2f", $2/1000}')
    fi
    if [[ -z "$cur_freq" ]]; then
        cur_freq=$(lscpu 2>/dev/null | awk -F: '/CPU MHz/ {gsub(/[ \t]/, "", $2); printf "%.2f", $2/1000}')
    fi

    # Cache
    cache_l2=$(lscpu 2>/dev/null | awk -F: '/L2 cache/ {gsub(/^[ \t]+/, "", $2); print $2}')
    cache_l3=$(lscpu 2>/dev/null | awk -F: '/L3 cache/ {gsub(/^[ \t]+/, "", $2); print $2}')

    # Architecture
    local arch
    arch=$(uname -m 2>/dev/null)

    echo -e "  ${BOLD}Model:${NC}       ${model:-Unknown}"
    echo -e "  ${BOLD}Arch:${NC}        ${arch:-Unknown}"
    echo -e "  ${BOLD}Cores:${NC}       ${cores} cores / ${threads} threads"
    [[ -n "$cur_freq" ]] && echo -e "  ${BOLD}Current:${NC}     ${cur_freq} GHz"
    [[ -n "$max_freq" ]] && echo -e "  ${BOLD}Max Freq:${NC}    ${max_freq} GHz"
    [[ -n "$cache_l2" ]] && echo -e "  ${BOLD}L2 Cache:${NC}    ${cache_l2}"
    [[ -n "$cache_l3" ]] && echo -e "  ${BOLD}L3 Cache:${NC}    ${cache_l3}"

    # Per-core frequencies
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        echo
        echo -e "  ${DIM}Per-core frequencies (GHz):${NC}"
        local core_freqs=""
        for cpu_dir in /sys/devices/system/cpu/cpu[0-9]*/cpufreq; do
            [[ -r "${cpu_dir}/scaling_cur_freq" ]] || continue
            local cfreq
            cfreq=$(cat "${cpu_dir}/scaling_cur_freq" 2>/dev/null)
            cfreq=$(awk "BEGIN {printf \"%.2f\", ${cfreq}/1000000}")
            core_freqs+="${cfreq} "
        done
        echo -e "  ${DIM}${core_freqs}${NC}"
    fi
}

# ── GPU Info ─────────────────────────────────────────────────────────────────
get_gpu_info() {
    draw_section "GPU"

    if ! command -v lspci &>/dev/null; then
        warn "lspci not found — install pciutils"
        return
    fi

    local gpu_lines
    gpu_lines=$(lspci 2>/dev/null | grep -iE 'VGA|3D|Display' || true)

    if [[ -z "$gpu_lines" ]]; then
        echo -e "  ${DIM}No GPU detected${NC}"
        return
    fi

    while IFS= read -r line; do
        local gpu_name
        gpu_name=$(echo "$line" | sed 's/.*: //')
        echo -e "  ${BOLD}GPU:${NC}         ${gpu_name}"
    done <<< "$gpu_lines"

    # VRAM from DRM sysfs
    for card_dir in /sys/class/drm/card[0-9]*/device; do
        [[ -d "$card_dir" ]] || continue
        if [[ -r "${card_dir}/mem_info_vram_total" ]]; then
            local vram_bytes
            vram_bytes=$(cat "${card_dir}/mem_info_vram_total" 2>/dev/null)
            if [[ -n "$vram_bytes" && "$vram_bytes" -gt 0 ]]; then
                local vram_gb
                vram_gb=$(awk "BEGIN {printf \"%.1f\", ${vram_bytes}/1073741824}")
                echo -e "  ${BOLD}VRAM:${NC}        ${vram_gb} GB"
            fi
        fi
    done

    # Driver info
    if command -v glxinfo &>/dev/null; then
        local gl_renderer gl_version
        gl_renderer=$(glxinfo 2>/dev/null | grep -i 'OpenGL renderer' | head -1 | cut -d: -f2 | xargs)
        gl_version=$(glxinfo 2>/dev/null | grep -i 'OpenGL version' | head -1 | cut -d: -f2 | xargs)
        [[ -n "$gl_renderer" ]] && echo -e "  ${BOLD}GL Renderer:${NC} ${gl_renderer}"
        [[ -n "$gl_version" ]] && echo -e "  ${BOLD}GL Version:${NC}  ${gl_version}"
    fi

    # Vulkan info
    if command -v vulkaninfo &>/dev/null; then
        local vk_device
        vk_device=$(vulkaninfo --summary 2>/dev/null | grep 'deviceName' | head -1 | sed 's/.*= //')
        local vk_api
        vk_api=$(vulkaninfo --summary 2>/dev/null | grep 'apiVersion' | head -1 | sed 's/.*= //')
        [[ -n "$vk_device" ]] && echo -e "  ${BOLD}Vulkan:${NC}      ${vk_device} (${vk_api})"
    fi

    # Kernel driver in use
    local drv
    drv=$(lspci -k 2>/dev/null | grep -A3 -iE 'VGA|3D|Display' | grep 'Kernel driver' | head -1 | awk '{print $NF}')
    [[ -n "$drv" ]] && echo -e "  ${BOLD}Driver:${NC}      ${drv}"
}

# ── RAM Info ─────────────────────────────────────────────────────────────────
get_ram_info() {
    draw_section "Memory"

    local total used available
    total=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')
    used=$(free -h 2>/dev/null | awk '/^Mem:/ {print $3}')
    available=$(free -h 2>/dev/null | awk '/^Mem:/ {print $7}')

    echo -e "  ${BOLD}Total:${NC}       ${total:-Unknown}"
    echo -e "  ${BOLD}Used:${NC}        ${used:-Unknown}"
    echo -e "  ${BOLD}Available:${NC}   ${available:-Unknown}"

    # Swap
    local swap_total swap_used
    swap_total=$(free -h 2>/dev/null | awk '/^Swap:/ {print $2}')
    swap_used=$(free -h 2>/dev/null | awk '/^Swap:/ {print $3}')
    if [[ -n "$swap_total" && "$swap_total" != "0B" ]]; then
        echo -e "  ${BOLD}Swap:${NC}        ${swap_used} / ${swap_total}"
    fi

    # Speed and type from dmidecode (requires root)
    if command -v dmidecode &>/dev/null && [[ $EUID -eq 0 ]]; then
        local mem_speed mem_type
        mem_speed=$(dmidecode -t memory 2>/dev/null | grep -m1 'Speed:' | grep -v 'Unknown' | awk '{print $2, $3}')
        mem_type=$(dmidecode -t memory 2>/dev/null | grep -m1 'Type:' | grep -v 'Unknown' | awk '{print $2}')
        [[ -n "$mem_speed" ]] && echo -e "  ${BOLD}Speed:${NC}       ${mem_speed}"
        [[ -n "$mem_type" ]] && echo -e "  ${BOLD}Type:${NC}        ${mem_type}"
    else
        echo -e "  ${DIM}(Run as root for RAM speed/type via dmidecode)${NC}"
    fi
}

# ── Storage Info ─────────────────────────────────────────────────────────────
get_storage_info() {
    draw_section "Storage"

    if command -v lsblk &>/dev/null; then
        echo -e "  ${BOLD}Block Devices:${NC}"
        echo
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${line}"
        done
    fi

    echo
    echo -e "  ${BOLD}Filesystem Usage:${NC}"
    echo
    df -h -x tmpfs -x devtmpfs -x squashfs 2>/dev/null | while IFS= read -r line; do
        echo -e "  ${line}"
    done
}

# ── Motherboard / BIOS ──────────────────────────────────────────────────────
get_mobo_info() {
    draw_section "Motherboard / BIOS"

    if command -v dmidecode &>/dev/null && [[ $EUID -eq 0 ]]; then
        local mobo_mfg mobo_name bios_vendor bios_ver bios_date
        mobo_mfg=$(dmidecode -s baseboard-manufacturer 2>/dev/null)
        mobo_name=$(dmidecode -s baseboard-product-name 2>/dev/null)
        bios_vendor=$(dmidecode -s bios-vendor 2>/dev/null)
        bios_ver=$(dmidecode -s bios-version 2>/dev/null)
        bios_date=$(dmidecode -s bios-release-date 2>/dev/null)

        echo -e "  ${BOLD}Board:${NC}       ${mobo_mfg} ${mobo_name}"
        echo -e "  ${BOLD}BIOS:${NC}        ${bios_vendor} ${bios_ver} (${bios_date})"
    else
        # Try sysfs fallback (doesn't require root on some systems)
        local board_vendor board_name
        board_vendor=$(cat /sys/devices/virtual/dmi/id/board_vendor 2>/dev/null || echo "")
        board_name=$(cat /sys/devices/virtual/dmi/id/board_name 2>/dev/null || echo "")
        local bios_vendor bios_ver bios_date
        bios_vendor=$(cat /sys/devices/virtual/dmi/id/bios_vendor 2>/dev/null || echo "")
        bios_ver=$(cat /sys/devices/virtual/dmi/id/bios_version 2>/dev/null || echo "")
        bios_date=$(cat /sys/devices/virtual/dmi/id/bios_date 2>/dev/null || echo "")

        if [[ -n "$board_vendor" || -n "$board_name" ]]; then
            echo -e "  ${BOLD}Board:${NC}       ${board_vendor} ${board_name}"
            echo -e "  ${BOLD}BIOS:${NC}        ${bios_vendor} ${bios_ver} (${bios_date})"
        else
            echo -e "  ${DIM}(Run as root for motherboard/BIOS info via dmidecode)${NC}"
        fi
    fi
}

# ── OS / Kernel ──────────────────────────────────────────────────────────────
get_os_info() {
    draw_section "OS / Kernel"

    local os_name os_ver kernel uptime_str

    if [[ -f /etc/os-release ]]; then
        os_name=$(. /etc/os-release && echo "${PRETTY_NAME:-$NAME}")
    else
        os_name=$(uname -o 2>/dev/null)
    fi

    kernel=$(uname -r 2>/dev/null)
    uptime_str=$(uptime -p 2>/dev/null || uptime 2>/dev/null)

    echo -e "  ${BOLD}OS:${NC}          ${os_name:-Unknown}"
    echo -e "  ${BOLD}Kernel:${NC}      ${kernel:-Unknown}"
    echo -e "  ${BOLD}Uptime:${NC}      ${uptime_str:-Unknown}"

    # Desktop environment
    [[ -n "${XDG_CURRENT_DESKTOP:-}" ]] && echo -e "  ${BOLD}Desktop:${NC}     ${XDG_CURRENT_DESKTOP}"
    [[ -n "${XDG_SESSION_TYPE:-}" ]] && echo -e "  ${BOLD}Session:${NC}     ${XDG_SESSION_TYPE}"
}

# ── Temperatures ─────────────────────────────────────────────────────────────
get_temp_info() {
    draw_section "Temperatures"

    if command -v sensors &>/dev/null; then
        sensors 2>/dev/null | while IFS= read -r line; do
            echo -e "  ${line}"
        done
    else
        # Fallback to sysfs thermal zones
        local found_any=false
        for tz in /sys/class/thermal/thermal_zone*; do
            [[ -d "$tz" ]] || continue
            local type temp
            type=$(cat "${tz}/type" 2>/dev/null || echo "zone")
            temp=$(cat "${tz}/temp" 2>/dev/null || echo "0")
            temp=$(awk "BEGIN {printf \"%.1f\", ${temp}/1000}")
            echo -e "  ${BOLD}${type}:${NC} ${temp}°C"
            found_any=true
        done
        if ! $found_any; then
            echo -e "  ${DIM}No temperature sensors found. Install lm-sensors: sudo apt install lm-sensors${NC}"
        fi
    fi
}

# ── Full System Info ─────────────────────────────────────────────────────────
show_system_info() {
    draw_header "System Information"
    get_os_info
    get_cpu_info
    get_gpu_info
    get_ram_info
    get_storage_info
    get_mobo_info
    get_temp_info
    press_any_key
}

# ── Quick Summary (for banner) ──────────────────────────────────────────────
get_quick_summary() {
    local cpu gpu ram kernel

    cpu=$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^[ \t]+/, "", $2); print $2; exit}')
    cpu=${cpu:-$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)}

    gpu=$(lspci 2>/dev/null | grep -iE 'VGA|3D' | head -1 | sed 's/.*: //' | sed 's/ (rev .*//')

    ram=$(free -h 2>/dev/null | awk '/^Mem:/ {print $2}')

    kernel=$(uname -r 2>/dev/null)

    echo -e "  ${DIM}CPU:${NC} ${cpu:-Unknown}"
    echo -e "  ${DIM}GPU:${NC} ${gpu:-Unknown}"
    echo -e "  ${DIM}RAM:${NC} ${ram:-Unknown}"
    echo -e "  ${DIM}Kernel:${NC} ${kernel:-Unknown}"
}
