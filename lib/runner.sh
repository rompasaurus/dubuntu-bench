#!/usr/bin/env bash
# runner.sh — Benchmark execution functions

# ── Helpers ──────────────────────────────────────────────────────────────────
require_tool() {
    local tool="$1"
    local name="${2:-$1}"

    if is_installed "$tool"; then
        return 0
    fi

    warn "${name} is not installed."
    if confirm "Install ${name} now?"; then
        install_tool "$tool"
        if is_installed "$tool"; then
            return 0
        fi
    fi

    err "${name} is required for this benchmark."
    return 1
}

confirm_run() {
    local name="$1"
    local desc="${2:-}"

    echo
    echo -e "  ${BOLD}${CYAN}${name}${NC}"
    [[ -n "$desc" ]] && echo -e "  ${DIM}${desc}${NC}"
    echo
    confirm "Run this benchmark?"
}

run_timed() {
    local name="$1"
    shift

    local start end elapsed
    start=$(date +%s)
    "$@"
    local rc=$?
    end=$(date +%s)
    elapsed=$(( end - start ))

    echo
    info "${name} completed in ${elapsed}s"
    return $rc
}

# ══════════════════════════════════════════════════════════════════════════════
# CPU BENCHMARKS
# ══════════════════════════════════════════════════════════════════════════════

run_stress_ng() {
    require_tool stress-ng "stress-ng" || return

    local duration=60
    echo
    printf "  ${BOLD}Duration in seconds${NC} ${DIM}[default: 60]${NC}: "
    read -r input
    [[ -n "$input" ]] && duration="$input"

    if ! confirm_run "stress-ng CPU stress test" "All cores, ${duration}s duration"; then
        return
    fi

    local threads
    threads=$(nproc)
    local logfile
    logfile=$(create_logfile "stress-ng")

    info "Running stress-ng with ${threads} workers for ${duration}s..."
    log_append "$logfile" "Command: stress-ng --cpu ${threads} --timeout ${duration}s --metrics-brief"
    log_append "$logfile" ""

    stress-ng --cpu "$threads" --timeout "${duration}s" --metrics-brief 2>&1 | tee -a "$logfile"

    log_result "stress-ng" "Completed ${duration}s stress test (${threads} threads)" "$logfile"
    press_any_key
}

run_sysbench_cpu() {
    require_tool sysbench "sysbench" || return

    if ! confirm_run "sysbench CPU" "Prime number calculation — single & multi-threaded"; then
        return
    fi

    local threads
    threads=$(nproc)
    local logfile
    logfile=$(create_logfile "sysbench-cpu")

    # Single-threaded
    info "Running sysbench CPU (single-threaded)..."
    log_append "$logfile" "── Single-threaded ──"
    sysbench cpu --threads=1 --time=30 run 2>&1 | tee -a "$logfile"

    echo
    log_append "$logfile" ""

    # Multi-threaded
    info "Running sysbench CPU (${threads} threads)..."
    log_append "$logfile" "── Multi-threaded (${threads} threads) ──"
    sysbench cpu --threads="$threads" --time=30 run 2>&1 | tee -a "$logfile"

    # Parse results
    local st_eps mt_eps
    st_eps=$(grep 'events per second' "$logfile" | head -1 | awk '{print $NF}')
    mt_eps=$(grep 'events per second' "$logfile" | tail -1 | awk '{print $NF}')

    log_result "sysbench-cpu" "ST: ${st_eps} eps, MT(${threads}t): ${mt_eps} eps" "$logfile"
    press_any_key
}

run_geekbench6() {
    require_tool geekbench6 "Geekbench 6" || return

    if ! confirm_run "Geekbench 6" "Full CPU benchmark — takes several minutes"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "geekbench6")

    info "Running Geekbench 6 (this may take 5-10 minutes)..."

    local gb_cmd="geekbench6"
    if [[ -x "${HOME}/.local/bin/geekbench6" ]]; then
        gb_cmd="${HOME}/.local/bin/geekbench6"
    fi

    "$gb_cmd" 2>&1 | tee -a "$logfile"

    # Parse result URL
    local result_url
    result_url=$(grep -oP 'https://browser\.geekbench\.com/v6/cpu/\d+' "$logfile" | tail -1)

    if [[ -n "$result_url" ]]; then
        echo
        success "Results: ${result_url}"
        log_result "geekbench6" "Results URL: ${result_url}" "$logfile"
    else
        log_result "geekbench6" "Completed (check log for details)" "$logfile"
    fi

    press_any_key
}

# ══════════════════════════════════════════════════════════════════════════════
# GPU BENCHMARKS
# ══════════════════════════════════════════════════════════════════════════════

run_glmark2() {
    require_tool glmark2 "glmark2" || return

    if ! confirm_run "glmark2" "OpenGL benchmark"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "glmark2")

    info "Running glmark2..."
    glmark2 2>&1 | tee -a "$logfile"

    # Parse score
    local score
    score=$(grep -oP 'glmark2 Score:\s*\K\d+' "$logfile" | tail -1)

    if [[ -n "$score" ]]; then
        success "glmark2 Score: ${score}"
        log_result "glmark2" "Score: ${score}" "$logfile"
    else
        log_result "glmark2" "Completed (check log for score)" "$logfile"
    fi

    press_any_key
}

run_vkmark() {
    require_tool vkmark "vkmark" || return

    if ! confirm_run "vkmark" "Vulkan benchmark"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "vkmark")

    info "Running vkmark..."
    vkmark 2>&1 | tee -a "$logfile"

    local score
    score=$(grep -oP 'vkmark Score:\s*\K\d+' "$logfile" | tail -1)

    if [[ -n "$score" ]]; then
        success "vkmark Score: ${score}"
        log_result "vkmark" "Score: ${score}" "$logfile"
    else
        log_result "vkmark" "Completed (check log for score)" "$logfile"
    fi

    press_any_key
}

run_unigine() {
    local engine="${1:-heaven}"
    local engine_upper="${engine^}"
    local bin_path=""

    # Check known paths
    case "$engine" in
        heaven)
            if [[ -x "${HOME}/.local/share/unigine/heaven/heaven" ]]; then
                bin_path="${HOME}/.local/share/unigine/heaven/heaven"
            elif command -v heaven &>/dev/null; then
                bin_path="heaven"
            fi
            ;;
        valley)
            if [[ -x "${HOME}/.local/share/unigine/valley/valley" ]]; then
                bin_path="${HOME}/.local/share/unigine/valley/valley"
            elif command -v valley &>/dev/null; then
                bin_path="valley"
            fi
            ;;
        superposition)
            if [[ -x "${HOME}/.local/share/unigine/superposition/Superposition" ]]; then
                bin_path="${HOME}/.local/share/unigine/superposition/Superposition"
            elif command -v superposition &>/dev/null; then
                bin_path="superposition"
            fi
            ;;
    esac

    if [[ -z "$bin_path" ]]; then
        warn "Unigine ${engine_upper} is not installed."
        install_unigine "$engine"
        return
    fi

    if ! confirm_run "Unigine ${engine_upper}" "GPU benchmark — launches a graphical window"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "unigine-${engine}")

    info "Launching Unigine ${engine_upper}..."
    log_append "$logfile" "Launched Unigine ${engine_upper} at $(date)"

    "$bin_path" 2>&1 | tee -a "$logfile"

    log_result "unigine-${engine}" "Completed (check log/screenshots for score)" "$logfile"
    press_any_key
}

# ══════════════════════════════════════════════════════════════════════════════
# MEMORY BENCHMARKS
# ══════════════════════════════════════════════════════════════════════════════

run_sysbench_memory() {
    require_tool sysbench "sysbench" || return

    if ! confirm_run "sysbench Memory" "Memory bandwidth test — read & write"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "sysbench-memory")

    info "Running sysbench memory (write)..."
    log_append "$logfile" "── Memory Write ──"
    sysbench memory --memory-block-size=1M --memory-total-size=10G --memory-oper=write run 2>&1 | tee -a "$logfile"

    echo
    log_append "$logfile" ""

    info "Running sysbench memory (read)..."
    log_append "$logfile" "── Memory Read ──"
    sysbench memory --memory-block-size=1M --memory-total-size=10G --memory-oper=read run 2>&1 | tee -a "$logfile"

    # Parse bandwidth
    local write_bw read_bw
    write_bw=$(grep -m1 'transferred' "$logfile" | grep -oP '[\d.]+\s*MiB/sec' | head -1)
    read_bw=$(grep 'transferred' "$logfile" | tail -1 | grep -oP '[\d.]+\s*MiB/sec')

    log_result "sysbench-memory" "Write: ${write_bw:-N/A}, Read: ${read_bw:-N/A}" "$logfile"
    press_any_key
}

run_mbw() {
    require_tool mbw "mbw" || return

    if ! confirm_run "mbw" "Memory bandwidth benchmark — MEMCPY, DUMB, MCBLOCK"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "mbw")

    info "Running mbw (256 MiB array)..."
    mbw -n 10 256 2>&1 | tee -a "$logfile"

    # Parse avg bandwidth
    local avg_bw
    avg_bw=$(grep 'AVG' "$logfile" | tail -1 | awk '{print $2, $3}')

    log_result "mbw" "Average bandwidth: ${avg_bw:-see log}" "$logfile"
    press_any_key
}

# ══════════════════════════════════════════════════════════════════════════════
# STORAGE BENCHMARKS
# ══════════════════════════════════════════════════════════════════════════════

run_fio() {
    require_tool fio "fio" || return

    if ! confirm_run "fio Storage Benchmark" "Sequential read/write + random 4K IOPS (file-based, safe)"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "fio")
    local test_dir="${RESULTS_DIR}/.fio_test"
    mkdir -p "$test_dir"

    # Sequential read
    info "fio: Sequential read (1GB)..."
    log_append "$logfile" "── Sequential Read ──"
    fio --name=seq_read --directory="$test_dir" --rw=read --bs=1M --size=1G \
        --numjobs=1 --time_based --runtime=30 --group_reporting 2>&1 | tee -a "$logfile"

    echo
    log_append "$logfile" ""

    # Sequential write
    info "fio: Sequential write (1GB)..."
    log_append "$logfile" "── Sequential Write ──"
    fio --name=seq_write --directory="$test_dir" --rw=write --bs=1M --size=1G \
        --numjobs=1 --time_based --runtime=30 --group_reporting 2>&1 | tee -a "$logfile"

    echo
    log_append "$logfile" ""

    # Random 4K IOPS
    info "fio: Random 4K read/write IOPS..."
    log_append "$logfile" "── Random 4K Read/Write ──"
    fio --name=rand_rw --directory="$test_dir" --rw=randrw --bs=4k --size=512M \
        --numjobs=4 --time_based --runtime=30 --group_reporting --ioengine=libaio \
        --iodepth=64 --direct=1 2>&1 | tee -a "$logfile"

    # Cleanup test files
    rm -rf "$test_dir"

    # Parse results
    local seq_read_bw seq_write_bw
    seq_read_bw=$(grep -A5 'seq_read' "$logfile" | grep -oP 'BW=\K[^,]+' | head -1)
    seq_write_bw=$(grep -A5 'seq_write' "$logfile" | grep -oP 'BW=\K[^,]+' | head -1)

    log_result "fio" "Seq Read: ${seq_read_bw:-see log}, Seq Write: ${seq_write_bw:-see log}" "$logfile"
    press_any_key
}

run_hdparm() {
    require_tool hdparm "hdparm" || return

    # Find the root device
    local root_dev
    root_dev=$(lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | head -1)
    root_dev="/dev/${root_dev}"

    if [[ ! -b "$root_dev" ]]; then
        # Fallback
        root_dev=$(lsblk -dno NAME | head -1)
        root_dev="/dev/${root_dev}"
    fi

    if ! confirm_run "hdparm" "Cached + buffered read speed test on ${root_dev}"; then
        return
    fi

    local logfile
    logfile=$(create_logfile "hdparm")

    info "Running hdparm on ${root_dev} (requires sudo)..."
    log_append "$logfile" "Device: ${root_dev}"
    log_append "$logfile" ""

    sudo hdparm -Tt "$root_dev" 2>&1 | tee -a "$logfile"

    # Parse results
    local cached buffered
    cached=$(grep 'cached reads' "$logfile" | awk '{print $(NF-1), $NF}')
    buffered=$(grep 'buffered disk reads' "$logfile" | awk '{print $(NF-1), $NF}')

    log_result "hdparm" "Cached: ${cached:-N/A}, Buffered: ${buffered:-N/A}" "$logfile"
    press_any_key
}

# ══════════════════════════════════════════════════════════════════════════════
# MONITORING
# ══════════════════════════════════════════════════════════════════════════════

run_temp_monitor() {
    if command -v s-tui &>/dev/null; then
        info "Launching s-tui (interactive CPU monitor)..."
        s-tui
    elif command -v sensors &>/dev/null; then
        info "Live temperature monitoring (Ctrl+C to stop)..."
        while true; do
            clear
            draw_header "Temperature Monitor"
            get_temp_info
            echo
            echo -e "  ${DIM}Refreshing every 2s... Press Ctrl+C to stop.${NC}"
            sleep 2
        done
    else
        warn "No temperature tools found."
        echo -e "  Install lm-sensors or s-tui:"
        echo -e "    sudo apt install lm-sensors s-tui"
        press_any_key
    fi
}

run_radeontop() {
    require_tool radeontop "radeontop" || return
    info "Launching radeontop (AMD GPU monitor)..."
    radeontop
}

# ══════════════════════════════════════════════════════════════════════════════
# PHORONIX TEST SUITE
# ══════════════════════════════════════════════════════════════════════════════

run_phoronix() {
    require_tool phoronix-test-suite "Phoronix Test Suite" || return

    draw_section "Phoronix Test Suite"

    echo -e "  ${BOLD}${CYAN}[1]${NC} List available tests"
    echo -e "  ${BOLD}${CYAN}[2]${NC} Run a specific test"
    echo -e "  ${BOLD}${CYAN}[3]${NC} System info"
    echo -e "  ${BOLD}${CYAN}[4]${NC} Interactive shell"
    echo -e "  ${BOLD}${CYAN}[0]${NC} Back"
    echo

    printf "  ${BOLD}Select: ${NC}"
    read -r -n 1 choice
    echo

    case "$choice" in
        1) phoronix-test-suite list-tests | less ;;
        2)
            printf "  ${BOLD}Test name (e.g. pts/compress-7zip): ${NC}"
            read -r test_name
            if [[ -n "$test_name" ]]; then
                local logfile
                logfile=$(create_logfile "phoronix-${test_name//\//-}")
                phoronix-test-suite benchmark "$test_name" 2>&1 | tee -a "$logfile"
                log_result "phoronix-${test_name}" "Completed" "$logfile"
            fi
            ;;
        3) phoronix-test-suite system-info; press_any_key ;;
        4) phoronix-test-suite shell ;;
        0) return ;;
    esac
}
