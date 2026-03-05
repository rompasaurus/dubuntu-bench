#!/usr/bin/env bash
# logger.sh — Result logging and viewer

RESULTS_DIR="${SCRIPT_DIR}/results"
SUMMARY_LOG="${RESULTS_DIR}/summary.log"

# ── Log File Management ─────────────────────────────────────────────────────
create_logfile() {
    local test_name="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d_%H-%M-%S')
    local logfile="${RESULTS_DIR}/${test_name}_${timestamp}.log"
    mkdir -p "$RESULTS_DIR"

    {
        echo "═══════════════════════════════════════════════════════"
        echo " dubuntu-bench — ${test_name}"
        echo " Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo " Host: $(hostname)"
        echo "═══════════════════════════════════════════════════════"
        echo
    } > "$logfile"

    echo "$logfile"
}

log_result() {
    local test_name="$1"
    local result="$2"
    local logfile="${3:-}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$RESULTS_DIR"

    # Append to summary log
    {
        echo "[${timestamp}] ${test_name}: ${result}"
    } >> "$SUMMARY_LOG"

    # Append to individual log if provided
    if [[ -n "$logfile" && -f "$logfile" ]]; then
        {
            echo "$result"
            echo
        } >> "$logfile"
    fi

    success "Result logged: ${test_name}"
}

log_append() {
    local logfile="$1"
    shift
    if [[ -n "$logfile" && -f "$logfile" ]]; then
        echo "$*" >> "$logfile"
    fi
}

# ── Result Viewer ────────────────────────────────────────────────────────────
view_results() {
    draw_header "Past Results"

    local logs=()
    while IFS= read -r -d '' f; do
        logs+=("$f")
    done < <(find "$RESULTS_DIR" -name '*.log' -type f -print0 2>/dev/null | sort -z -r)

    if [[ ${#logs[@]} -eq 0 ]]; then
        warn "No results found in ${RESULTS_DIR}/"
        press_any_key
        return
    fi

    echo -e "  ${BOLD}Available result files:${NC}"
    echo

    local i=1
    for f in "${logs[@]}"; do
        local fname
        fname=$(basename "$f")
        local fsize
        fsize=$(du -h "$f" 2>/dev/null | cut -f1)
        local fdate
        fdate=$(stat -c '%y' "$f" 2>/dev/null | cut -d. -f1)
        echo -e "  ${CYAN}[${i}]${NC} ${fname}  ${DIM}(${fsize}, ${fdate})${NC}"
        (( i++ ))
    done

    echo -e "  ${CYAN}[s]${NC} View summary log"
    echo -e "  ${CYAN}[0]${NC} Back"
    echo

    printf "  ${BOLD}Select: ${NC}"
    read -r choice

    if [[ "$choice" == "s" ]]; then
        if [[ -f "$SUMMARY_LOG" ]]; then
            less "$SUMMARY_LOG"
        else
            warn "No summary log found."
            press_any_key
        fi
    elif [[ "$choice" == "0" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#logs[@]} )); then
        less "${logs[$((choice - 1))]}"
    else
        warn "Invalid selection."
        press_any_key
    fi
}
