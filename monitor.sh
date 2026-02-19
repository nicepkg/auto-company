#!/bin/bash
# ============================================================
# Auto Company — Live Monitor
# ============================================================
# Watch the auto-loop output in real-time.
#
# Usage:
#   ./monitor.sh            # Tail the main log
#   ./monitor.sh --last     # Show last cycle's full output
#   ./monitor.sh --status   # Show current loop status
#   ./monitor.sh --cycles   # Summary of all cycles
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
LOG_DIR="$PROJECT_DIR/logs"
STATE_FILE="$PROJECT_DIR/.auto-loop-state"
PID_FILE="$PROJECT_DIR/.auto-loop.pid"
PAUSE_FLAG="$PROJECT_DIR/.auto-loop-paused"

LABEL="com.autocompany.loop"
SYSTEMD_UNIT="autocompany-loop.service"
SYSTEMD_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/${SYSTEMD_UNIT}"
OS="$(uname -s)"

print_daemon_status() {
    if [ -f "$PAUSE_FLAG" ]; then
        echo "Daemon: PAUSED (.auto-loop-paused present)"
        return
    fi

    if [ "$OS" = "Darwin" ]; then
        if launchctl list 2>/dev/null | grep -q "$LABEL"; then
            echo "Daemon: LOADED ($LABEL via launchd)"
        else
            echo "Daemon: NOT LOADED"
        fi
        return
    fi

    if [ "$OS" = "Linux" ]; then
        if ! command -v systemctl &>/dev/null; then
            echo "Daemon: UNKNOWN (systemctl not found)"
            return
        fi

        if systemctl --user is-active --quiet "$SYSTEMD_UNIT" 2>/dev/null; then
            echo "Daemon: ACTIVE ($SYSTEMD_UNIT via systemd --user)"
        elif systemctl --user is-enabled --quiet "$SYSTEMD_UNIT" 2>/dev/null; then
            echo "Daemon: ENABLED (inactive) ($SYSTEMD_UNIT)"
        elif [ -f "$SYSTEMD_PATH" ]; then
            echo "Daemon: INSTALLED (not enabled) ($SYSTEMD_UNIT)"
        else
            echo "Daemon: NOT LOADED"
        fi
        return
    fi

    echo "Daemon: UNKNOWN (unsupported OS: $OS)"
}

case "${1:-}" in
    --status)
        echo "=== Auto Company Status ==="
        if [ -f "$PID_FILE" ]; then
            pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo "Loop: RUNNING (PID $pid)"
            else
                echo "Loop: STOPPED (stale PID $pid)"
            fi
        else
            echo "Loop: NOT RUNNING"
        fi

        print_daemon_status

        if [ -f "$STATE_FILE" ]; then
            echo ""
            cat "$STATE_FILE"
        fi

        echo ""
        echo "=== Latest Consensus ==="
        if [ -f "$PROJECT_DIR/memories/consensus.md" ]; then
            head -30 "$PROJECT_DIR/memories/consensus.md"
        else
            echo "(no consensus file)"
        fi

        echo ""
        echo "=== Recent Log ==="
        if [ -f "$LOG_DIR/auto-loop.log" ]; then
            tail -20 "$LOG_DIR/auto-loop.log"
        fi
        ;;

    --last)
        latest=$(ls -t "$LOG_DIR"/cycle-*.log 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            echo "=== Latest Cycle: $(basename "$latest") ==="
            if command -v jq &>/dev/null && jq -r '.result' "$latest" 2>/dev/null | grep -qv "^null$"; then
                jq -r '.result' "$latest"
            elif command -v jq &>/dev/null; then
                # Codex JSONL logs: print the final assistant message if available.
                message=$(jq -Rr 'fromjson? | select(.type=="item.completed" and .item.type=="agent_message") | .item.text // empty' "$latest" | tail -1)
                if [ -n "$message" ]; then
                    echo "$message"
                else
                    cat "$latest"
                fi
            else
                cat "$latest"
            fi
        else
            echo "No cycle logs found."
        fi
        ;;

    --cycles)
        echo "=== Cycle History ==="
        if [ -f "$LOG_DIR/auto-loop.log" ]; then
            grep -E "Cycle #[0-9]+ \[(OK|FAIL|START|LIMIT|BUDGET|BREAKER)\]" "$LOG_DIR/auto-loop.log" | tail -50
        else
            echo "No log found."
        fi
        ;;

    *)
        echo "=== Auto Company Live Monitor (Ctrl+C to stop) ==="
        echo "Watching: $LOG_DIR/auto-loop.log"
        echo ""
        if [ -f "$LOG_DIR/auto-loop.log" ]; then
            tail -f "$LOG_DIR/auto-loop.log"
        else
            echo "No log file yet. Start the loop first: ./auto-loop.sh"
        fi
        ;;
esac
