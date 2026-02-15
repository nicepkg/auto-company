#!/bin/bash
# ============================================================
# Auto Company — 24/7 Autonomous Loop
# ============================================================
# Keeps Codex CLI running continuously to drive the AI team.
# Uses fresh sessions with consensus.md as the relay baton.
#
# Usage:
#   ./auto-loop.sh              # Run in foreground
#   ./auto-loop.sh --daemon     # Run via OS daemon manager (no tty)
#
# Stop:
#   ./stop-loop.sh              # Graceful stop
#   kill $(cat .auto-loop.pid)  # Force stop
#
# Config (env vars):
#   MODEL=gpt-5.3-codex         # Codex model (default: gpt-5.3-codex)
#   REASONING_EFFORT=high       # Reasoning effort (default: high)
#   LOOP_INTERVAL=30            # Seconds between cycles (default: 30)
#   CYCLE_TIMEOUT_SECONDS=1800  # Max seconds per cycle before force-kill
#   MAX_CONSECUTIVE_ERRORS=5    # Circuit breaker threshold
#   COOLDOWN_SECONDS=300        # Cooldown after circuit break
#   LIMIT_WAIT_SECONDS=3600     # Wait on usage limit
#   MAX_LOGS=200                # Max cycle logs to keep
# ============================================================

set -euo pipefail

# === Resolve project root (always relative to this script) ===
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

LOG_DIR="$PROJECT_DIR/logs"
CONSENSUS_FILE="$PROJECT_DIR/memories/consensus.md"
PROMPT_FILE="$PROJECT_DIR/PROMPT.md"
PID_FILE="$PROJECT_DIR/.auto-loop.pid"
STATE_FILE="$PROJECT_DIR/.auto-loop-state"

# Loop settings (all overridable via env vars)
MODEL="${MODEL:-gpt-5.3-codex}"
REASONING_EFFORT="${REASONING_EFFORT:-high}"
LOOP_INTERVAL="${LOOP_INTERVAL:-30}"
CYCLE_TIMEOUT_SECONDS="${CYCLE_TIMEOUT_SECONDS:-1800}"
MAX_CONSECUTIVE_ERRORS="${MAX_CONSECUTIVE_ERRORS:-5}"
COOLDOWN_SECONDS="${COOLDOWN_SECONDS:-300}"
LIMIT_WAIT_SECONDS="${LIMIT_WAIT_SECONDS:-3600}"
MAX_LOGS="${MAX_LOGS:-200}"

# === Functions ===

now_ts() {
    # When trapping shutdown signals under service managers, external `date`
    # can be interrupted. Fall back to bash's time formatter.
    date '+%Y-%m-%d %H:%M:%S' 2>/dev/null \
        || printf '%(%Y-%m-%d %H:%M:%S)T\n' -1 2>/dev/null \
        || echo "unknown-time"
}

log() {
    local timestamp
    timestamp=$(now_ts)
    local msg="[$timestamp] $1"
    echo "$msg" >> "$LOG_DIR/auto-loop.log"
    if [ -t 1 ]; then
        echo "$msg"
    fi
}

log_cycle() {
    local cycle_num=$1
    local status=$2
    local msg=$3
    local timestamp
    timestamp=$(now_ts)
    echo "[$timestamp] Cycle #$cycle_num [$status] $msg" >> "$LOG_DIR/auto-loop.log"
    if [ -t 1 ]; then
        echo "[$timestamp] Cycle #$cycle_num [$status] $msg"
    fi
}

check_usage_limit() {
    local output="$1"
    if echo "$output" | grep -qi "usage limit\|rate limit\|too many requests\|resource_exhausted\|overloaded\|quota"; then
        return 0
    fi
    return 1
}

check_stop_requested() {
    if [ -f "$PROJECT_DIR/.auto-loop-stop" ]; then
        rm -f "$PROJECT_DIR/.auto-loop-stop"
        return 0
    fi
    return 1
}

save_state() {
    cat > "$STATE_FILE" << EOF
LOOP_COUNT=$loop_count
ERROR_COUNT=$error_count
LAST_RUN=$(now_ts)
STATUS=$1
MODEL=$MODEL
REASONING_EFFORT=$REASONING_EFFORT
EOF
}

cleanup() {
    log "=== Auto Loop Shutting Down (PID $$) ==="
    rm -f "$PID_FILE"
    save_state "stopped"
    exit 0
}

rotate_logs() {
    # Keep only the latest N cycle logs
    local count
    count=$(find "$LOG_DIR" -name "cycle-*.log" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt "$MAX_LOGS" ]; then
        local to_delete=$((count - MAX_LOGS))
        find "$LOG_DIR" -name "cycle-*.log" -type f | sort | head -n "$to_delete" | xargs rm -f 2>/dev/null || true
        log "Log rotation: removed $to_delete old cycle logs"
    fi

    # Keep only the latest N cycle prompt files
    local prompt_count
    prompt_count=$(find "$LOG_DIR" -name "cycle-*-prompt.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$prompt_count" -gt "$MAX_LOGS" ]; then
        local prompts_to_delete=$((prompt_count - MAX_LOGS))
        find "$LOG_DIR" -name "cycle-*-prompt.md" -type f | sort | head -n "$prompts_to_delete" | xargs rm -f 2>/dev/null || true
        log "Prompt rotation: removed $prompts_to_delete old cycle prompts"
    fi

    # Rotate main log if over 10MB
    local log_size
    log_size=$(stat -f%z "$LOG_DIR/auto-loop.log" 2>/dev/null || stat -c%s "$LOG_DIR/auto-loop.log" 2>/dev/null || echo 0)
    if [ "$log_size" -gt 10485760 ]; then
        mv "$LOG_DIR/auto-loop.log" "$LOG_DIR/auto-loop.log.old"
        log "Main log rotated (was ${log_size} bytes)"
    fi
}

backup_consensus() {
    if [ -f "$CONSENSUS_FILE" ]; then
        cp "$CONSENSUS_FILE" "$CONSENSUS_FILE.bak"
    fi
}

restore_consensus() {
    if [ -f "$CONSENSUS_FILE.bak" ]; then
        cp "$CONSENSUS_FILE.bak" "$CONSENSUS_FILE"
        log "Consensus restored from backup after failed cycle"
    fi
}

validate_consensus() {
    if [ ! -s "$CONSENSUS_FILE" ]; then
        return 1
    fi
    if ! grep -q "^# Auto Company Consensus" "$CONSENSUS_FILE"; then
        return 1
    fi
    if ! grep -q "^## Next Action" "$CONSENSUS_FILE"; then
        return 1
    fi
    if ! grep -q "^## Company State" "$CONSENSUS_FILE"; then
        return 1
    fi
    return 0
}

run_codex_cycle() {
    local prompt_file="$1"
    local output_file timeout_flag last_message_file
    local -a cmd

    output_file=$(mktemp)
    timeout_flag=$(mktemp)
    last_message_file=$(mktemp)

    set +e
    (
        cd "$PROJECT_DIR"
        cmd=(codex exec - \
            --json \
            --skip-git-repo-check \
            --dangerously-bypass-approvals-and-sandbox \
            -c "reasoning.effort=\"$REASONING_EFFORT\"" \
            -c "model_reasoning_effort=\"$REASONING_EFFORT\"" \
            -o "$last_message_file")
        if [ -n "$MODEL" ]; then
            cmd+=(--model "$MODEL")
        fi
        "${cmd[@]}" < "$prompt_file"
    ) > "$output_file" 2>&1 &
    local codex_pid=$!

    (
        sleep "$CYCLE_TIMEOUT_SECONDS"
        if kill -0 "$codex_pid" 2>/dev/null; then
            echo "1" > "$timeout_flag"
            kill -TERM "$codex_pid" 2>/dev/null || true
            sleep 5
            kill -KILL "$codex_pid" 2>/dev/null || true
        fi
    ) &
    local watchdog_pid=$!

    wait "$codex_pid"
    EXIT_CODE=$?

    kill "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
    set -e

    OUTPUT=$(cat "$output_file")
    OUTPUT_LAST_MESSAGE=$(cat "$last_message_file" 2>/dev/null || true)
    rm -f "$output_file"
    rm -f "$last_message_file"

    if [ -s "$timeout_flag" ]; then
        CYCLE_TIMED_OUT=1
        EXIT_CODE=124
    else
        CYCLE_TIMED_OUT=0
    fi
    rm -f "$timeout_flag"
}

extract_cycle_metadata() {
    RESULT_TEXT="${OUTPUT_LAST_MESSAGE:-}"
    CYCLE_COST=""
    CYCLE_SUBTYPE="success"
    CYCLE_TYPE="codex.exec"
    CYCLE_INPUT_TOKENS=""
    CYCLE_OUTPUT_TOKENS=""
    CYCLE_CACHED_INPUT_TOKENS=""

    if command -v jq &>/dev/null; then
        if [ -z "$RESULT_TEXT" ]; then
            RESULT_TEXT=$(echo "$OUTPUT" | jq -Rr 'fromjson? | select(.type=="item.completed" and .item.type=="agent_message") | .item.text // empty' | tail -1 | head -c 2000 || true)
        fi
        CYCLE_INPUT_TOKENS=$(echo "$OUTPUT" | jq -Rr 'fromjson? | select(.type=="turn.completed") | .usage.input_tokens // empty' | tail -1 || true)
        CYCLE_OUTPUT_TOKENS=$(echo "$OUTPUT" | jq -Rr 'fromjson? | select(.type=="turn.completed") | .usage.output_tokens // empty' | tail -1 || true)
        CYCLE_CACHED_INPUT_TOKENS=$(echo "$OUTPUT" | jq -Rr 'fromjson? | select(.type=="turn.completed") | .usage.cached_input_tokens // empty' | tail -1 || true)
        CYCLE_COST=$(echo "$OUTPUT" | jq -Rr 'fromjson? | select(.type=="turn.completed") | .usage.total_cost_usd // empty' | tail -1 || true)
        if echo "$OUTPUT" | jq -Rr 'fromjson? | select(.type=="error") | .type' | head -1 | grep -q "error"; then
            CYCLE_SUBTYPE="error"
        fi
    else
        if [ -z "$RESULT_TEXT" ]; then
            RESULT_TEXT=$(echo "$OUTPUT" | tail -c 2000 || true)
        fi
        if echo "$OUTPUT" | grep -q '"type":"error"'; then
            CYCLE_SUBTYPE="error"
        fi
    fi
}

# === Setup ===

mkdir -p "$LOG_DIR" "$PROJECT_DIR/memories"

# Clean up stale stop file from previous run
rm -f "$PROJECT_DIR/.auto-loop-stop"

# Check for existing instance
if [ -f "$PID_FILE" ]; then
    existing_pid=$(cat "$PID_FILE")
    if kill -0 "$existing_pid" 2>/dev/null; then
        echo "Auto loop already running (PID $existing_pid). Stop it first with ./stop-loop.sh"
        exit 1
    fi
fi

# Check dependencies
if ! command -v codex &>/dev/null; then
    echo "Error: 'codex' CLI not found in PATH. Install Codex CLI first."
    exit 1
fi

if [ ! -f "$PROMPT_FILE" ]; then
    echo "Error: PROMPT.md not found at $PROMPT_FILE"
    exit 1
fi

# Write PID file
echo $$ > "$PID_FILE"

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT SIGHUP

# Initialize counters
loop_count=0
error_count=0

log "=== Auto Company Loop Started (PID $$) ==="
log "Project: $PROJECT_DIR"
log "Model: $MODEL (effort: $REASONING_EFFORT) | Interval: ${LOOP_INTERVAL}s | Timeout: ${CYCLE_TIMEOUT_SECONDS}s | Breaker: ${MAX_CONSECUTIVE_ERRORS} errors"

# === Main Loop ===

while true; do
    # Check for stop request
    if check_stop_requested; then
        log "Stop requested. Shutting down gracefully."
        cleanup
    fi

    loop_count=$((loop_count + 1))
    cycle_log="$LOG_DIR/cycle-$(printf '%04d' $loop_count)-$(date '+%Y%m%d-%H%M%S').log"

    log_cycle $loop_count "START" "Beginning work cycle"
    save_state "running"

    # Log rotation
    rotate_logs

    # Backup consensus before cycle
    backup_consensus

    # Build prompt with consensus pre-injected
    PROMPT=$(cat "$PROMPT_FILE")
    CONSENSUS=$(cat "$CONSENSUS_FILE" 2>/dev/null || echo "No consensus file found. This is the very first cycle.")
    cycle_prompt="$LOG_DIR/cycle-$(printf '%04d' $loop_count)-prompt.md"
    cat > "$cycle_prompt" << EOF
$PROMPT

---

## Current Consensus (pre-loaded, do NOT re-read this file)

$CONSENSUS

---

This is Cycle #$loop_count. Act decisively.
EOF

    # Run Codex in headless mode with per-cycle timeout
    run_codex_cycle "$cycle_prompt"

    # Save full output to cycle log
    echo "$OUTPUT" > "$cycle_log"

    # Extract result fields for status classification
    extract_cycle_metadata

    cycle_failed_reason=""
    if [ "$CYCLE_TIMED_OUT" -eq 1 ]; then
        cycle_failed_reason="Timed out after ${CYCLE_TIMEOUT_SECONDS}s"
    elif [ $EXIT_CODE -ne 0 ]; then
        cycle_failed_reason="Exit code $EXIT_CODE"
    elif [ "$CYCLE_SUBTYPE" != "success" ]; then
        cycle_failed_reason="Non-success subtype '${CYCLE_SUBTYPE:-unknown}'"
    elif ! validate_consensus; then
        cycle_failed_reason="consensus.md validation failed after cycle"
    fi

    if [ -z "$cycle_failed_reason" ]; then
        token_msg=""
        if [ -n "$CYCLE_INPUT_TOKENS" ] || [ -n "$CYCLE_OUTPUT_TOKENS" ]; then
            token_msg=", tokens in/out: ${CYCLE_INPUT_TOKENS:-?}/${CYCLE_OUTPUT_TOKENS:-?}"
            if [ -n "$CYCLE_CACHED_INPUT_TOKENS" ]; then
                token_msg="${token_msg}, cached in: ${CYCLE_CACHED_INPUT_TOKENS}"
            fi
        fi
        log_cycle $loop_count "OK" "Completed (cost: \$${CYCLE_COST:-unknown}, subtype: ${CYCLE_SUBTYPE:-unknown}${token_msg})"
        if [ -n "$RESULT_TEXT" ]; then
            log_cycle $loop_count "SUMMARY" "$(echo "$RESULT_TEXT" | head -c 300)"
        fi
        error_count=0
    else
        error_count=$((error_count + 1))
        log_cycle $loop_count "FAIL" "$cycle_failed_reason (cost: \$${CYCLE_COST:-unknown}, subtype: ${CYCLE_SUBTYPE:-unknown}, errors: $error_count/$MAX_CONSECUTIVE_ERRORS)"

        # Restore consensus on failure
        restore_consensus

        # Check for usage limit
        if check_usage_limit "$OUTPUT"; then
            log_cycle $loop_count "LIMIT" "API usage limit detected. Waiting ${LIMIT_WAIT_SECONDS}s..."
            save_state "waiting_limit"
            sleep $LIMIT_WAIT_SECONDS
            error_count=0
            continue
        fi

        # Circuit breaker
        if [ $error_count -ge $MAX_CONSECUTIVE_ERRORS ]; then
            log_cycle $loop_count "BREAKER" "Circuit breaker tripped! Cooling down ${COOLDOWN_SECONDS}s..."
            save_state "circuit_break"
            sleep $COOLDOWN_SECONDS
            error_count=0
            log "Circuit breaker reset. Resuming..."
        fi
    fi

    save_state "idle"
    log_cycle $loop_count "WAIT" "Sleeping ${LOOP_INTERVAL}s before next cycle..."
    sleep $LOOP_INTERVAL
done
