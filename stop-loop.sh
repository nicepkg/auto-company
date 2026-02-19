#!/bin/bash
# ============================================================
# Auto Company — Stop Loop
# ============================================================
# Gracefully stops the auto-loop process.
# Can also pause/resume daemon mode:
# - macOS: launchd
# - Linux: systemd user service
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"
PID_FILE="$PROJECT_DIR/.auto-loop.pid"
PAUSE_FLAG="$PROJECT_DIR/.auto-loop-paused"

LABEL="com.autocompany.loop"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"

SYSTEMD_UNIT="autocompany-loop.service"
SYSTEMD_PATH="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/${SYSTEMD_UNIT}"

OS="$(uname -s)"

stop_loop_process() {
    # Method 1: Signal file (graceful, waits for current cycle to finish)
    touch "$PROJECT_DIR/.auto-loop-stop"
    echo "Stop signal sent. Loop will stop after current cycle completes."

    # Method 2: Also send SIGTERM if PID file exists
    if [ -f "$PID_FILE" ]; then
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Sending SIGTERM to PID $pid..."
            kill -TERM "$pid"
        else
            echo "Process $pid not running. Cleaning up PID file."
            rm -f "$PID_FILE"
        fi
    else
        echo "No PID file found."
    fi
}

pause_daemon() {
    touch "$PAUSE_FLAG"
    echo "Pause flag created: $PAUSE_FLAG"
    stop_loop_process

    if [ "$OS" = "Darwin" ]; then
        if launchctl list 2>/dev/null | grep -q "$LABEL"; then
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
            echo "launchd daemon unloaded."
        fi
    elif [ "$OS" = "Linux" ]; then
        if command -v systemctl &>/dev/null; then
            systemctl --user disable --now "$SYSTEMD_UNIT" 2>/dev/null || true
            systemctl --user daemon-reload 2>/dev/null || true
            echo "systemd user service disabled and stopped."
        fi
    fi

    echo "Daemon paused. Resume with: ./stop-loop.sh --resume-daemon"
}

resume_daemon() {
    rm -f "$PAUSE_FLAG"
    echo "Pause flag removed."

    if [ "$OS" = "Darwin" ]; then
        if [ ! -f "$PLIST_PATH" ]; then
            echo "LaunchAgent plist not found: $PLIST_PATH"
            echo "Install daemon first: ./install-daemon.sh"
            exit 1
        fi

        if launchctl list 2>/dev/null | grep -q "$LABEL"; then
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
        fi

        launchctl load "$PLIST_PATH"
        echo "launchd daemon resumed and started."
    elif [ "$OS" = "Linux" ]; then
        if [ ! -f "$SYSTEMD_PATH" ]; then
            echo "systemd unit not found: $SYSTEMD_PATH"
            echo "Install daemon first: ./install-daemon.sh"
            exit 1
        fi

        if ! command -v systemctl &>/dev/null; then
            echo "Error: systemctl not found."
            exit 1
        fi

        systemctl --user daemon-reload
        systemctl --user enable --now "$SYSTEMD_UNIT"
        echo "systemd user service resumed and started."
    else
        echo "Unsupported OS: $OS"
        exit 1
    fi
}

case "${1:-}" in
    --pause-daemon)
        pause_daemon
        ;;
    --resume-daemon)
        resume_daemon
        ;;
    --help|-h)
        echo "Usage:"
        echo "  ./stop-loop.sh                 # Stop current loop process"
        echo "  ./stop-loop.sh --pause-daemon  # Pause daemon and stop loop"
        echo "  ./stop-loop.sh --resume-daemon # Resume daemon"
        ;;
    *)
        stop_loop_process
        ;;
esac
