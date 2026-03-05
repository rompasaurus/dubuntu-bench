#!/usr/bin/env bash
set -euo pipefail

# ── Resolve Script Directory ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Source Libraries ─────────────────────────────────────────────────────────
source "${SCRIPT_DIR}/lib/colors.sh"
source "${SCRIPT_DIR}/lib/logger.sh"
source "${SCRIPT_DIR}/lib/system_info.sh"
source "${SCRIPT_DIR}/lib/installer.sh"
source "${SCRIPT_DIR}/lib/runner.sh"

# ── Version ──────────────────────────────────────────────────────────────────
VERSION="1.0.0"

# ── CLI Usage ────────────────────────────────────────────────────────────────
usage() {
    echo -e "${BOLD}dubuntu-bench${NC} v${VERSION} — System Benchmarking & Info Tool"
    echo
    echo -e "${BOLD}Usage:${NC}"
    echo "  bench.sh                  Launch interactive menu"
    echo "  bench.sh --info           Print system information"
    echo "  bench.sh --install all    Install all benchmark dependencies"
    echo "  bench.sh --run <test>     Run a specific benchmark"
    echo "  bench.sh --status         Show install status of all tools"
    echo "  bench.sh --results        View past benchmark results"
    echo "  bench.sh --help           Show this help message"
    echo
    echo -e "${BOLD}Available tests:${NC}"
    echo "  stress-ng         CPU stress test (all cores)"
    echo "  sysbench-cpu      sysbench prime number test (ST + MT)"
    echo "  geekbench6        Geekbench 6 full benchmark"
    echo "  glmark2           OpenGL benchmark"
    echo "  vkmark            Vulkan benchmark"
    echo "  unigine-heaven    Unigine Heaven GPU benchmark"
    echo "  unigine-valley    Unigine Valley GPU benchmark"
    echo "  sysbench-memory   Memory bandwidth test"
    echo "  mbw               Memory bandwidth (MEMCPY/DUMB/MCBLOCK)"
    echo "  fio               Storage sequential + random IOPS"
    echo "  hdparm            Disk cached + buffered read speed"
    echo
    echo -e "${BOLD}Examples:${NC}"
    echo "  ./bench.sh --run sysbench-cpu"
    echo "  ./bench.sh --install all"
    echo "  ./bench.sh --info"
}

# ── CLI Run Dispatcher ───────────────────────────────────────────────────────
cli_run_test() {
    local test="$1"
    case "$test" in
        stress-ng)        run_stress_ng ;;
        sysbench-cpu)     run_sysbench_cpu ;;
        geekbench6)       run_geekbench6 ;;
        glmark2)          run_glmark2 ;;
        vkmark)           run_vkmark ;;
        unigine-heaven)   run_unigine heaven ;;
        unigine-valley)   run_unigine valley ;;
        sysbench-memory)  run_sysbench_memory ;;
        mbw)              run_mbw ;;
        fio)              run_fio ;;
        hdparm)           run_hdparm ;;
        *)
            err "Unknown test: ${test}"
            echo "Run './bench.sh --help' for available tests."
            exit 1
            ;;
    esac
}

# ── Sub-Menus ────────────────────────────────────────────────────────────────
menu_cpu() {
    while true; do
        draw_banner
        draw_section "CPU Benchmarks"

        echo -e "  ${BOLD}${CYAN}[1]${NC}  $(tool_status stress-ng "stress-ng — CPU stress test")"
        echo -e "  ${BOLD}${CYAN}[2]${NC}  $(tool_status sysbench "sysbench — Prime number test")"
        echo -e "  ${BOLD}${CYAN}[3]${NC}  $(tool_status geekbench6 "Geekbench 6 — Full benchmark")"
        echo -e "  ${DIM}$(draw_line 40 ─)${NC}"
        echo -e "  ${BOLD}${CYAN}[i]${NC}  Install all CPU tools"
        echo -e "  ${BOLD}${CYAN}[0]${NC}  Back"
        echo

        printf "  ${BOLD}Select: ${NC}"
        read -r -n 1 choice
        echo

        case "$choice" in
            1) run_stress_ng ;;
            2) run_sysbench_cpu ;;
            3) run_geekbench6 ;;
            i) install_category cpu ; press_any_key ;;
            0) return ;;
            *) warn "Invalid option" ;;
        esac
    done
}

menu_gpu() {
    while true; do
        draw_banner
        draw_section "GPU Benchmarks"

        echo -e "  ${BOLD}${CYAN}[1]${NC}  $(tool_status glmark2 "glmark2 — OpenGL benchmark")"
        echo -e "  ${BOLD}${CYAN}[2]${NC}  $(tool_status vkmark "vkmark — Vulkan benchmark")"
        echo -e "  ${BOLD}${CYAN}[3]${NC}  $(tool_status unigine-heaven "Unigine Heaven")"
        echo -e "  ${BOLD}${CYAN}[4]${NC}  $(tool_status unigine-valley "Unigine Valley")"
        echo -e "  ${BOLD}${CYAN}[5]${NC}  $(tool_status unigine-superposition "Unigine Superposition")"
        echo -e "  ${DIM}$(draw_line 40 ─)${NC}"
        echo -e "  ${BOLD}${CYAN}[i]${NC}  Install all GPU tools"
        echo -e "  ${BOLD}${CYAN}[0]${NC}  Back"
        echo

        printf "  ${BOLD}Select: ${NC}"
        read -r -n 1 choice
        echo

        case "$choice" in
            1) run_glmark2 ;;
            2) run_vkmark ;;
            3) run_unigine heaven ;;
            4) run_unigine valley ;;
            5) run_unigine superposition ;;
            i) install_category gpu ; press_any_key ;;
            0) return ;;
            *) warn "Invalid option" ;;
        esac
    done
}

menu_memory() {
    while true; do
        draw_banner
        draw_section "Memory Benchmarks"

        echo -e "  ${BOLD}${CYAN}[1]${NC}  $(tool_status sysbench "sysbench — Memory bandwidth")"
        echo -e "  ${BOLD}${CYAN}[2]${NC}  $(tool_status mbw "mbw — Memory bandwidth")"
        echo -e "  ${DIM}$(draw_line 40 ─)${NC}"
        echo -e "  ${BOLD}${CYAN}[i]${NC}  Install all memory tools"
        echo -e "  ${BOLD}${CYAN}[0]${NC}  Back"
        echo

        printf "  ${BOLD}Select: ${NC}"
        read -r -n 1 choice
        echo

        case "$choice" in
            1) run_sysbench_memory ;;
            2) run_mbw ;;
            i) install_category memory ; press_any_key ;;
            0) return ;;
            *) warn "Invalid option" ;;
        esac
    done
}

menu_storage() {
    while true; do
        draw_banner
        draw_section "Storage Benchmarks"

        echo -e "  ${BOLD}${CYAN}[1]${NC}  $(tool_status fio "fio — Sequential + random IOPS")"
        echo -e "  ${BOLD}${CYAN}[2]${NC}  $(tool_status hdparm "hdparm — Cached/buffered reads")"
        echo -e "  ${DIM}$(draw_line 40 ─)${NC}"
        echo -e "  ${BOLD}${CYAN}[i]${NC}  Install all storage tools"
        echo -e "  ${BOLD}${CYAN}[0]${NC}  Back"
        echo

        printf "  ${BOLD}Select: ${NC}"
        read -r -n 1 choice
        echo

        case "$choice" in
            1) run_fio ;;
            2) run_hdparm ;;
            i) install_category storage ; press_any_key ;;
            0) return ;;
            *) warn "Invalid option" ;;
        esac
    done
}

# ── Main Menu ────────────────────────────────────────────────────────────────
main_menu() {
    while true; do
        draw_banner
        get_quick_summary
        echo

        echo -e "  ${BOLD}${CYAN}[1]${NC}  System Information"
        echo -e "  ${BOLD}${CYAN}[2]${NC}  CPU Benchmarks"
        echo -e "  ${BOLD}${CYAN}[3]${NC}  GPU Benchmarks"
        echo -e "  ${BOLD}${CYAN}[4]${NC}  Memory Benchmarks"
        echo -e "  ${BOLD}${CYAN}[5]${NC}  Storage Benchmarks"
        echo -e "  ${BOLD}${CYAN}[6]${NC}  Phoronix Test Suite"
        echo -e "  ${BOLD}${CYAN}[7]${NC}  Temperature Monitor"
        echo -e "  ${BOLD}${CYAN}[8]${NC}  Install All Dependencies"
        echo -e "  ${BOLD}${CYAN}[9]${NC}  View Past Results"
        echo -e "  ${DIM}$(draw_line 40 ─)${NC}"
        echo -e "  ${BOLD}${CYAN}[s]${NC}  Tool Install Status"
        echo -e "  ${BOLD}${CYAN}[0]${NC}  Exit"
        echo

        printf "  ${BOLD}Select option: ${NC}"
        read -r -n 1 choice
        echo

        case "$choice" in
            1) show_system_info ;;
            2) menu_cpu ;;
            3) menu_gpu ;;
            4) menu_memory ;;
            5) menu_storage ;;
            6) run_phoronix ;;
            7) run_temp_monitor ;;
            8) install_all ;;
            9) view_results ;;
            s) show_install_status ; press_any_key ;;
            0|q)
                echo
                echo -e "  ${DIM}Goodbye!${NC}"
                echo
                exit 0
                ;;
            *) warn "Invalid option" ;;
        esac
    done
}

# ── CLI Argument Parsing ────────────────────────────────────────────────────
main() {
    if [[ $# -eq 0 ]]; then
        main_menu
        return
    fi

    case "${1:-}" in
        --help|-h)
            usage
            ;;
        --info)
            draw_header "System Information"
            get_os_info
            get_cpu_info
            get_gpu_info
            get_ram_info
            get_storage_info
            get_mobo_info
            get_temp_info
            ;;
        --install)
            shift
            if [[ "${1:-}" == "all" ]]; then
                install_all
            elif [[ -n "${1:-}" ]]; then
                install_tool "$1"
            else
                err "Specify a tool name or 'all'"
                exit 1
            fi
            ;;
        --run)
            shift
            if [[ -n "${1:-}" ]]; then
                cli_run_test "$1"
            else
                err "Specify a test name. Run --help for available tests."
                exit 1
            fi
            ;;
        --status)
            show_install_status
            ;;
        --results)
            view_results
            ;;
        *)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
}

main "$@"
