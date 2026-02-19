#!/usr/bin/env bash
#
# e2e_demo.sh — End-to-end demo of the WritersRoom workflow
#
# Runs through the complete Producer -> Writer -> Director -> Actor pipeline.
#
# Usage:
#   bash e2e_demo.sh [OPTIONS]
#
# Options:
#   --provider NAME    LLM provider (default: ollama)
#   --model NAME       Model name (default: gpt-oss:20b)
#   --max-lines N      Max dialog lines per scene (default: 20)
#   --dir PATH         Directory to create the project in (default: PWD)
#   --skip-llm         Only run non-LLM steps (useful for CI)
#

# ---------------------------------------------------------------------------
# Configuration & defaults
# ---------------------------------------------------------------------------

PROVIDER="ollama"
MODEL="gpt-oss:20b"
MAX_LINES=20
PROJECT_DIR=""
SKIP_LLM=false

EXAMPLES_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR=$EXAMPLES_DIR/..
PROJECTS_DIR=$EXAMPLES_DIR/projects
DEMO_DIR=""
START_TIME=""

# Use BUNDLE_GEMFILE so `bundle exec` works from any directory.
export BUNDLE_GEMFILE="$ROOT_DIR/Gemfile"
WR="bundle exec $ROOT_DIR/bin/wr"

# ---------------------------------------------------------------------------
# Color helpers (respect NO_COLOR)
# ---------------------------------------------------------------------------

if [[ -z "${NO_COLOR:-}" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

banner() {
    echo ""
    echo -e "${CYAN}${BOLD}==================================================================${RESET}"
    echo -e "${CYAN}${BOLD}  $1${RESET}"
    echo -e "${CYAN}${BOLD}==================================================================${RESET}"
    echo ""
}

info() { echo -e "${GREEN}[INFO]${RESET}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
err() { echo -e "${RED}[ERROR]${RESET} $*"; }
step() { echo -e "${BOLD}>>> $*${RESET}"; }

# ---------------------------------------------------------------------------
# run_cmd — run a command, print it, allow failure in LLM mode
# ---------------------------------------------------------------------------

# Shorten command display: replace the full bundle exec path with just "wr"
pretty_cmd() {
    echo "$*" | sed "s|bundle exec $ROOT_DIR/bin/wr|wr|"
}

run_cmd() {
    step "$(pretty_cmd "$*")"
    eval "$@"
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        warn "Command exited with status $rc"
    fi
    echo ""
    return $rc
}

# Run an LLM-requiring command. Skipped when --skip-llm is active.
run_llm() {
    if $SKIP_LLM; then
        warn "Skipping (--skip-llm): $(pretty_cmd "$*")"
        echo ""
        return 0
    fi
    run_cmd "$@"
}

# ---------------------------------------------------------------------------
# Parse CLI arguments
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
    case "$1" in
    --provider)
        PROVIDER="$2"
        shift 2
        ;;
    --model)
        MODEL="$2"
        shift 2
        ;;
    --max-lines)
        MAX_LINES="$2"
        shift 2
        ;;
    --dir)
        PROJECT_DIR="$2"
        shift 2
        ;;
    --skip-llm)
        SKIP_LLM=true
        shift
        ;;
    -h | --help)
        echo "Usage: bash e2e_demo.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --provider NAME    LLM provider (default: ollama)"
        echo "  --model NAME       Model name (default: gpt-oss:20b)"
        echo "  --max-lines N      Max dialog lines per scene (default: 20)"
        echo "  --dir PATH         Directory to create the project in (default: PWD)"
        echo "  --skip-llm         Only run non-LLM steps (useful for CI)"
        echo "  -h, --help         Show this help"
        exit 0
        ;;
    *)
        err "Unknown option: $1"
        exit 1
        ;;
    esac
done

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

START_TIME=$SECONDS

banner "WritersRoom End-to-End Demo"

echo -e "  Provider:   ${BOLD}${PROVIDER}${RESET}"
echo -e "  Model:      ${BOLD}${MODEL}${RESET}"
echo -e "  Max lines:  ${BOLD}${MAX_LINES}${RESET}"
echo -e "  Skip LLM:   ${BOLD}${SKIP_LLM}${RESET}"
echo ""

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

banner "Checking Prerequisites"

cd "$ROOT_DIR" || {
    err "Cannot cd to $ROOT_DIR"
    exit 1
}

step "Verifying 'wr' CLI is available..."
if ! $WR version >/dev/null 2>&1; then
    err "'$WR version' failed. Run 'bundle install' in $ROOT_DIR first."
    exit 1
fi
info "CLI is available."
echo ""

# Create the demo project in the specified directory (default: PWD)
if [[ -n "$PROJECT_DIR" ]]; then
    mkdir -p "$PROJECT_DIR"
    DEMO_PARENT="$(cd "$PROJECT_DIR" && pwd)"
else
    DEMO_PARENT="$(pwd)"
fi
DEMO_DIR="$DEMO_PARENT/detective_story"

info "Demo project will be created at: $DEMO_DIR"

# ===================================================================
# Phase 1 — Producer: Initialize (no LLM)
# ===================================================================

banner "Phase 1: Producer — Initialize Project"

cd "$DEMO_PARENT" || exit 1

run_cmd "$WR init detective_story \
  -p '$PROVIDER' \
  -m '$MODEL' \
  -c 'A detective investigates a series of mysterious disappearances in a foggy coastal town'"

cd "$DEMO_DIR" || {
    err "Demo project directory not created"
    exit 1
}

# Point WR at the project by staying in its directory. The CLI reads config.yml
# from the current working directory.

run_cmd "$WR config"

# ===================================================================
# Phase 2 — Writer: Develop Story (LLM required)
# ===================================================================

banner "Phase 2: Writer — Develop Story"

run_llm "$WR write develop-concept"

run_llm "$WR write develop-character 'Detective Sarah' \
  -p 'sharp and intuitive' \
  -b 'Former forensic scientist turned detective'"

run_llm "$WR write develop-character 'Officer Mike' \
  -p 'by-the-book but loyal' \
  -b 'Grew up in the coastal town'"

run_llm "$WR write create-arc 'Investigation Begins' \
  -d 'The first disappearance is reported and the detective arrives'"

run_llm "$WR write breakdown-scenes 'Investigation Begins' -n 3"

run_llm "$WR write list-arcs"

# ===================================================================
# Phase 3 — Producer: Create Assets (no LLM)
# ===================================================================

banner "Phase 3: Producer — Create Characters & Scenes"

run_cmd "$WR character create 'Detective Sarah' \
  -p sharp \
  -s 'direct and questioning' \
  -b 'Former forensic scientist turned detective'"

run_cmd "$WR character create 'Officer Mike' \
  -p methodical \
  -s 'formal but supportive' \
  -b 'Grew up in the coastal town'"

run_cmd "$WR character list"

run_cmd "$WR scene create 'First Report' \
  -d 'Detective Sarah arrives and Officer Mike briefs her on the disappearance' \
  -c 'Detective Sarah' 'Officer Mike'"

run_cmd "$WR scene create 'The Docks' \
  -d 'Sarah and Mike investigate the docks where the missing person was last seen' \
  -c 'Detective Sarah' 'Officer Mike'"

run_cmd "$WR scene list"

# ===================================================================
# Phase 4 — Director: Shoot a Scene (LLM required)
# ===================================================================

banner "Phase 4: Director — Shoot a Scene"

FIRST_SCENE="$(ls scenes/*.md 2>/dev/null | head -1)"

if [[ -n "$FIRST_SCENE" ]]; then
    run_llm "$WR direct '$FIRST_SCENE' -l $MAX_LINES"
else
    warn "No scene files found to direct."
fi

# ===================================================================
# Phase 5 — Producer: Full Production + Report
# ===================================================================

banner "Phase 5: Producer — Full Production & Report"

run_llm "$WR produce -l $MAX_LINES"

run_cmd "$WR report"

# ===================================================================
# Phase 6 — Show Results
# ===================================================================

banner "Phase 6: Results"

info "Project directory: $DEMO_DIR"
echo ""

step "Project file tree:"
if command -v tree >/dev/null 2>&1; then
    tree "$DEMO_DIR" --noreport
else
    find "$DEMO_DIR" -type f | sort | while read -r f; do
        echo "  ${f#$DEMO_DIR/}"
    done
fi

echo ""

# Show transcript excerpts if any exist
TRANSCRIPTS=(transcripts/*.txt)
if [[ -e "${TRANSCRIPTS[0]}" ]]; then
    step "Transcript excerpts:"
    for t in "${TRANSCRIPTS[@]}"; do
        echo -e "\n${CYAN}--- $(basename "$t") ---${RESET}"
        head -20 "$t"
        TOTAL=$(wc -l <"$t")
        if [[ "$TOTAL" -gt 20 ]]; then
            echo -e "${YELLOW}  ... ($TOTAL total lines)${RESET}"
        fi
    done
else
    if $SKIP_LLM; then
        info "No transcripts generated (LLM steps were skipped)."
    else
        warn "No transcripts found."
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

ELAPSED=$((SECONDS - START_TIME))
MINUTES=$((ELAPSED / 60))
SECS=$((ELAPSED % 60))

banner "Demo Complete"

echo -e "  Elapsed time:  ${BOLD}${MINUTES}m ${SECS}s${RESET}"
echo -e "  Project dir:   ${BOLD}${DEMO_DIR}${RESET}"
echo ""
info "To explore: cd $DEMO_DIR"
