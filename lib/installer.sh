#!/usr/bin/env bash
# installer.sh — Tool registry, install dispatchers

# ── Tool Registry ────────────────────────────────────────────────────────────
# APT-installable tools: command -> package name
declare -A APT_TOOLS=(
    [stress-ng]="stress-ng"
    [sysbench]="sysbench"
    [glmark2]="glmark2"
    [vkmark]="vkmark"
    [fio]="fio"
    [hdparm]="hdparm"
    [mbw]="mbw"
    [sensors]="lm-sensors"
    [s-tui]="s-tui"
    [radeontop]="radeontop"
)

# Categories for organized display
declare -A TOOL_CATEGORIES=(
    [cpu]="stress-ng sysbench"
    [gpu]="glmark2 vkmark"
    [memory]="mbw"
    [storage]="fio hdparm"
    [monitoring]="sensors s-tui radeontop"
)

# Custom tools (not APT)
CUSTOM_TOOLS=("geekbench6" "phoronix-test-suite" "unigine-heaven" "unigine-valley" "unigine-superposition")

# ── Install Checks ──────────────────────────────────────────────────────────
is_installed() {
    local tool="$1"
    case "$tool" in
        geekbench6)
            command -v geekbench6 &>/dev/null || [[ -x "${HOME}/.local/bin/geekbench6" ]]
            ;;
        phoronix-test-suite)
            command -v phoronix-test-suite &>/dev/null
            ;;
        unigine-heaven)
            [[ -x "${HOME}/.local/share/unigine/heaven/heaven" ]] || command -v heaven &>/dev/null
            ;;
        unigine-valley)
            [[ -x "${HOME}/.local/share/unigine/valley/valley" ]] || command -v valley &>/dev/null
            ;;
        unigine-superposition)
            [[ -x "${HOME}/.local/share/unigine/superposition/Superposition" ]] || command -v superposition &>/dev/null
            ;;
        sensors)
            command -v sensors &>/dev/null
            ;;
        *)
            command -v "$tool" &>/dev/null
            ;;
    esac
}

tool_status() {
    local tool="$1"
    local name="${2:-$tool}"
    if is_installed "$tool"; then
        echo -e "${name} ${CHECK}"
    else
        echo -e "${name} ${CROSS}"
    fi
}

# ── APT Installer ───────────────────────────────────────────────────────────
install_apt_tool() {
    local cmd="$1"
    local pkg="${APT_TOOLS[$cmd]:-$cmd}"

    if is_installed "$cmd"; then
        success "${cmd} is already installed"
        return 0
    fi

    info "Installing ${pkg} via apt..."
    if sudo apt-get install -y "$pkg"; then
        success "${pkg} installed successfully"
        return 0
    else
        err "Failed to install ${pkg}"
        return 1
    fi
}

# ── Custom Installers ───────────────────────────────────────────────────────
install_geekbench6() {
    if is_installed geekbench6; then
        success "Geekbench 6 is already installed"
        return 0
    fi

    info "Installing Geekbench 6..."

    local install_dir="${HOME}/.local/share/geekbench6"
    local bin_dir="${HOME}/.local/bin"
    mkdir -p "$install_dir" "$bin_dir"

    local arch
    arch=$(uname -m)
    local url="https://cdn.geekbench.com/Geekbench-6.4.0-Linux.tar.gz"

    info "Downloading Geekbench 6..."
    local tmpfile
    tmpfile=$(mktemp /tmp/geekbench6-XXXXXX.tar.gz)

    if ! curl -fSL -o "$tmpfile" "$url"; then
        err "Failed to download Geekbench 6"
        rm -f "$tmpfile"
        return 1
    fi

    info "Extracting to ${install_dir}..."
    if ! tar -xzf "$tmpfile" -C "$install_dir" --strip-components=1; then
        err "Failed to extract Geekbench 6"
        rm -f "$tmpfile"
        return 1
    fi
    rm -f "$tmpfile"

    # Symlink to PATH
    ln -sf "${install_dir}/geekbench6" "${bin_dir}/geekbench6"

    # Ensure ~/.local/bin is in PATH
    if [[ ":${PATH}:" != *":${bin_dir}:"* ]]; then
        export PATH="${bin_dir}:${PATH}"
        warn "Added ${bin_dir} to PATH for this session."
        warn "Add 'export PATH=\"\${HOME}/.local/bin:\${PATH}\"' to your shell profile for persistence."
    fi

    success "Geekbench 6 installed"
}

install_phoronix() {
    if is_installed phoronix-test-suite; then
        success "Phoronix Test Suite is already installed"
        return 0
    fi

    info "Installing Phoronix Test Suite..."

    local url="https://phoronix-test-suite.com/releases/repo/pts.debian/files/phoronix-test-suite_10.8.4_all.deb"
    local tmpfile
    tmpfile=$(mktemp /tmp/phoronix-XXXXXX.deb)

    info "Downloading Phoronix Test Suite..."
    if ! curl -fSL -o "$tmpfile" "$url"; then
        err "Failed to download Phoronix Test Suite"
        rm -f "$tmpfile"
        return 1
    fi

    info "Installing .deb package..."
    if sudo dpkg -i "$tmpfile"; then
        sudo apt-get install -f -y 2>/dev/null  # fix dependencies
        success "Phoronix Test Suite installed"
    else
        sudo apt-get install -f -y 2>/dev/null
        if command -v phoronix-test-suite &>/dev/null; then
            success "Phoronix Test Suite installed (after fixing dependencies)"
        else
            err "Failed to install Phoronix Test Suite"
            rm -f "$tmpfile"
            return 1
        fi
    fi

    rm -f "$tmpfile"
}

install_unigine() {
    local engine="$1"  # heaven, valley, or superposition
    local install_dir="${HOME}/.local/share/unigine/${engine}"

    if is_installed "unigine-${engine}"; then
        success "Unigine ${engine^} is already installed"
        return 0
    fi

    info "Unigine ${engine^} requires manual download."
    echo
    echo -e "  ${BOLD}Instructions:${NC}"
    echo -e "  1. Visit: ${CYAN}https://benchmark.unigine.com/${engine}/${NC}"
    echo -e "  2. Download the Linux .run installer"
    echo -e "  3. Make it executable: chmod +x Unigine_${engine^}*.run"
    echo -e "  4. Run it: ./Unigine_${engine^}*.run"
    echo -e "     Or install to: ${install_dir}"
    echo
    echo -e "  ${DIM}Alternatively, install from Steam if available.${NC}"

    press_any_key
}

# ── Install Dispatcher ──────────────────────────────────────────────────────
install_tool() {
    local tool="$1"

    case "$tool" in
        geekbench6)
            install_geekbench6
            ;;
        phoronix-test-suite)
            install_phoronix
            ;;
        unigine-heaven|unigine-valley|unigine-superposition)
            local engine="${tool#unigine-}"
            install_unigine "$engine"
            ;;
        *)
            if [[ -n "${APT_TOOLS[$tool]+x}" ]]; then
                install_apt_tool "$tool"
            else
                err "Unknown tool: ${tool}"
                return 1
            fi
            ;;
    esac
}

# ── Batch Installers ────────────────────────────────────────────────────────
install_all_apt() {
    info "Installing all APT-based benchmark tools..."
    echo

    local packages=()
    for cmd in "${!APT_TOOLS[@]}"; do
        if ! is_installed "$cmd"; then
            packages+=("${APT_TOOLS[$cmd]}")
        fi
    done

    if [[ ${#packages[@]} -eq 0 ]]; then
        success "All APT tools are already installed"
        return 0
    fi

    info "Packages to install: ${packages[*]}"
    if confirm "Install ${#packages[@]} packages via apt?"; then
        sudo apt-get update
        sudo apt-get install -y "${packages[@]}"
        success "APT tools installed"
    fi
}

install_all() {
    draw_header "Install All Dependencies"

    install_all_apt
    echo

    for tool in "${CUSTOM_TOOLS[@]}"; do
        if ! is_installed "$tool"; then
            echo
            install_tool "$tool"
        fi
    done

    echo
    success "Installation complete"
    press_any_key
}

install_category() {
    local category="$1"
    local tools="${TOOL_CATEGORIES[$category]:-}"

    if [[ -z "$tools" ]]; then
        err "Unknown category: ${category}"
        return 1
    fi

    info "Installing ${category} tools..."
    for tool in $tools; do
        install_tool "$tool"
    done

    success "${category} tools installation complete"
}

# ── Show Install Status ─────────────────────────────────────────────────────
show_install_status() {
    draw_section "Tool Status"

    echo -e "  ${BOLD}APT Tools:${NC}"
    for cmd in stress-ng sysbench glmark2 vkmark fio hdparm mbw sensors s-tui radeontop; do
        if [[ -n "${APT_TOOLS[$cmd]+x}" ]]; then
            echo -e "    $(tool_status "$cmd")"
        fi
    done

    echo
    echo -e "  ${BOLD}Custom Tools:${NC}"
    echo -e "    $(tool_status geekbench6 "Geekbench 6")"
    echo -e "    $(tool_status phoronix-test-suite "Phoronix Test Suite")"
    echo -e "    $(tool_status unigine-heaven "Unigine Heaven")"
    echo -e "    $(tool_status unigine-valley "Unigine Valley")"
    echo -e "    $(tool_status unigine-superposition "Unigine Superposition")"
}
