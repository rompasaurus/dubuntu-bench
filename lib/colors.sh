#!/usr/bin/env bash
# colors.sh — ANSI colors, box-drawing, TUI helpers

# ── Color Constants ──────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Unicode symbols
CHECK="${GREEN}✔${NC}"
CROSS="${RED}✘${NC}"
ARROW="${CYAN}➜${NC}"
BULLET="${BLUE}●${NC}"

# ── Message Helpers ──────────────────────────────────────────────────────────
info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*" >&2; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }

# ── Box Drawing ──────────────────────────────────────────────────────────────
draw_line() {
    local width=${1:-60}
    local char=${2:-─}
    printf '%*s' "$width" '' | tr ' ' "$char"
    echo
}

draw_header() {
    local title="$1"
    local width=${2:-60}
    local pad=$(( (width - ${#title} - 2) / 2 ))
    echo
    echo -e "${CYAN}╔$(printf '%*s' "$width" '' | tr ' ' '═')╗${NC}"
    echo -e "${CYAN}║${NC}$(printf '%*s' "$pad" '')${BOLD}${WHITE} ${title} ${NC}$(printf '%*s' "$(( width - pad - ${#title} - 2 ))" '')${CYAN}║${NC}"
    echo -e "${CYAN}╚$(printf '%*s' "$width" '' | tr ' ' '═')╝${NC}"
}

draw_box_top() {
    local width=${1:-60}
    echo -e "${DIM}┌$(printf '%*s' "$width" '' | tr ' ' '─')┐${NC}"
}

draw_box_mid() {
    local text="$1"
    local width=${2:-60}
    local stripped
    stripped=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    local textlen=${#stripped}
    local pad=$(( width - textlen ))
    (( pad < 0 )) && pad=0
    echo -e "${DIM}│${NC} ${text}$(printf '%*s' "$pad" '')${DIM}│${NC}"
}

draw_box_bot() {
    local width=${1:-60}
    echo -e "${DIM}└$(printf '%*s' "$width" '' | tr ' ' '─')┘${NC}"
}

draw_section() {
    local title="$1"
    echo
    echo -e "  ${BOLD}${BLUE}── ${title} ──${NC}"
    echo
}

# ── Banner ───────────────────────────────────────────────────────────────────
draw_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
     ┌─────────────────────────────────────────────┐
     │     _       _                 _              │
     │  __| |_   _| |__  _   _ _ __| |_ _   _      │
     │ / _` | | | | '_ \| | | | '__| __| | | |     │
     │| (_| | |_| | |_) | |_| | |  | |_| |_| |     │
     │ \__,_|\__,_|_.__/ \__,_|_|   \__|\__,_|     │
     │              BENCH                           │
     └─────────────────────────────────────────────┘
BANNER
    echo -e "${NC}"
    echo -e "  ${DIM}System Benchmarking & Info Tool${NC}"
    echo -e "  ${DIM}$(draw_line 45 ─)${NC}"
}

# ── Menu Rendering ───────────────────────────────────────────────────────────
# show_menu "Title" "option1" "option2" ...
# Returns the selected number via the global MENU_CHOICE variable
show_menu() {
    local title="$1"
    shift
    local options=("$@")

    draw_section "$title"

    local i=1
    for opt in "${options[@]}"; do
        if [[ "$opt" == ---* ]]; then
            echo -e "  ${DIM}$(draw_line 40 ─)${NC}"
        else
            local key
            if (( i == ${#options[@]} )); then
                key="0"
            else
                key="$i"
            fi
            echo -e "  ${BOLD}${CYAN}[${key}]${NC}  ${opt}"
            (( i++ ))
        fi
    done

    echo
    printf "  ${BOLD}Select option: ${NC}"
    read -r -n 1 MENU_CHOICE
    echo
}

# show_menu_indexed — like show_menu but keys always match array index
# Stores choice in MENU_CHOICE
show_menu_indexed() {
    local title="$1"
    shift
    local options=("$@")

    draw_section "$title"

    for i in "${!options[@]}"; do
        local opt="${options[$i]}"
        if [[ "$opt" == ---* ]]; then
            echo -e "  ${DIM}$(draw_line 40 ─)${NC}"
        else
            echo -e "  ${BOLD}${CYAN}[${i}]${NC}  ${opt}"
        fi
    done

    echo
    printf "  ${BOLD}Select option: ${NC}"
    read -r -n 1 MENU_CHOICE
    echo
}

# ── Install Status ───────────────────────────────────────────────────────────
status_icon() {
    if command -v "$1" &>/dev/null; then
        echo -e "${CHECK}"
    else
        echo -e "${CROSS}"
    fi
}

status_label() {
    local cmd="$1"
    local name="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        echo -e "${name} ${CHECK}"
    else
        echo -e "${name} ${CROSS}"
    fi
}

# ── Utility ──────────────────────────────────────────────────────────────────
press_any_key() {
    echo
    printf "  ${DIM}Press any key to continue...${NC}"
    read -r -n 1 -s
    echo
}

confirm() {
    local msg="${1:-Continue?}"
    printf "  ${YELLOW}%s${NC} ${DIM}[y/N]${NC} " "$msg"
    read -r -n 1 reply
    echo
    [[ "$reply" =~ ^[Yy]$ ]]
}
