#!/bin/bash
# ============================================================
# Auto Company — Install/Uninstall Daemon
# ============================================================
# macOS: launchd LaunchAgent
# Linux: systemd user service
#
# Usage:
#   ./install-daemon.sh             # Install and start
#   ./install-daemon.sh --uninstall # Stop and remove
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAUSE_FLAG="${SCRIPT_DIR}/.auto-loop-paused"

LABEL="com.autocompany.loop"
PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"

SYSTEMD_UNIT="autocompany-loop.service"
SYSTEMD_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
SYSTEMD_PATH="${SYSTEMD_DIR}/${SYSTEMD_UNIT}"

OS="$(uname -s)"

if [ "$OS" != "Darwin" ] && [ "$OS" != "Linux" ]; then
    echo "Unsupported OS: $OS (supported: macOS, Linux)"
    exit 1
fi

# Check dependencies
if ! command -v codex &>/dev/null; then
    echo "Error: 'codex' CLI not found. Install Codex CLI first."
    exit 1
fi

CODEX_PATH="$(command -v codex)"
CODEX_DIR="$(dirname "$CODEX_PATH")"

# Detect node path (for wrangler/npx)
NODE_DIR=""
if command -v node &>/dev/null; then
    NODE_DIR="$(dirname "$(command -v node)")"
fi

# Build PATH: include common macOS and Linux tool dirs
DAEMON_PATH="${CODEX_DIR}"
[ -n "$NODE_DIR" ] && DAEMON_PATH="${DAEMON_PATH}:${NODE_DIR}"
DAEMON_PATH="${DAEMON_PATH}:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

uninstall_macos() {
    echo "Uninstalling Auto Company launchd daemon..."
    if launchctl list 2>/dev/null | grep -q "$LABEL"; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
        echo "Service unloaded."
    fi
    if [ -f "$PLIST_PATH" ]; then
        rm -f "$PLIST_PATH"
        echo "Plist removed: $PLIST_PATH"
    fi
    echo "Done. Daemon uninstalled."
}

install_macos() {
    echo "Installing Auto Company launchd daemon..."
    echo "  Project: $SCRIPT_DIR"
    echo "  Codex:   $CODEX_PATH"
    echo "  PATH:    $DAEMON_PATH"

    mkdir -p "$HOME/Library/LaunchAgents" "$SCRIPT_DIR/logs"
    rm -f "$PAUSE_FLAG"

    if launchctl list 2>/dev/null | grep -q "$LABEL"; then
        launchctl unload "$PLIST_PATH" 2>/dev/null || true
    fi

    cat > "$PLIST_PATH" << EOF_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${SCRIPT_DIR}/auto-loop.sh</string>
        <string>--daemon</string>
    </array>

    <key>WorkingDirectory</key>
    <string>${SCRIPT_DIR}</string>

    <key>KeepAlive</key>
    <dict>
        <key>PathState</key>
        <dict>
            <key>${PAUSE_FLAG}</key>
            <false/>
        </dict>
    </dict>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>${SCRIPT_DIR}/logs/launchd-stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${SCRIPT_DIR}/logs/launchd-stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${DAEMON_PATH}</string>
        <key>HOME</key>
        <string>${HOME}</string>
    </dict>

    <key>ThrottleInterval</key>
    <integer>30</integer>
</dict>
</plist>
EOF_PLIST

    echo "Plist written: $PLIST_PATH"

    launchctl load "$PLIST_PATH"
    echo ""
    echo "launchd daemon installed and started."
}

uninstall_linux() {
    echo "Uninstalling Auto Company systemd user service..."
    if command -v systemctl &>/dev/null; then
        systemctl --user disable --now "$SYSTEMD_UNIT" 2>/dev/null || true
        systemctl --user daemon-reload 2>/dev/null || true
        systemctl --user reset-failed "$SYSTEMD_UNIT" 2>/dev/null || true
    fi

    if [ -f "$SYSTEMD_PATH" ]; then
        rm -f "$SYSTEMD_PATH"
        echo "Unit removed: $SYSTEMD_PATH"
    fi

    if command -v systemctl &>/dev/null; then
        systemctl --user daemon-reload 2>/dev/null || true
    fi

    echo "Done. Daemon uninstalled."
}

install_linux() {
    if ! command -v systemctl &>/dev/null; then
        echo "Error: systemctl not found. Linux daemon mode requires systemd user services."
        exit 1
    fi

    echo "Installing Auto Company systemd user service..."
    echo "  Project: $SCRIPT_DIR"
    echo "  Codex:   $CODEX_PATH"
    echo "  PATH:    $DAEMON_PATH"

    mkdir -p "$SYSTEMD_DIR" "$SCRIPT_DIR/logs"
    rm -f "$PAUSE_FLAG"

    cat > "$SYSTEMD_PATH" << EOF_UNIT
[Unit]
Description=Auto Company Loop
After=network-online.target
Wants=network-online.target
ConditionPathExists=!${PAUSE_FLAG}

[Service]
Type=simple
WorkingDirectory=${SCRIPT_DIR}
Environment=PATH=${DAEMON_PATH}
Environment=HOME=${HOME}
ExecStart=/bin/bash ${SCRIPT_DIR}/auto-loop.sh --daemon
Restart=always
RestartSec=5
KillSignal=SIGTERM
TimeoutStopSec=30

[Install]
WantedBy=default.target
EOF_UNIT

    echo "Unit written: $SYSTEMD_PATH"

    if ! systemctl --user daemon-reload; then
        echo "Error: failed to talk to systemd user manager."
        echo "Hint: run this from a user login session with systemd --user available."
        exit 1
    fi
    if ! systemctl --user enable --now "$SYSTEMD_UNIT"; then
        echo "Error: failed to enable/start $SYSTEMD_UNIT."
        exit 1
    fi

    echo ""
    echo "systemd user service installed and started."
    echo "Tip: run 'loginctl enable-linger $USER' if you want it to keep running after logout/reboot."
}

if [ "${1:-}" = "--uninstall" ]; then
    if [ "$OS" = "Darwin" ]; then
        uninstall_macos
    else
        uninstall_linux
    fi
    exit 0
fi

if [ "$OS" = "Darwin" ]; then
    install_macos
else
    install_linux
fi

echo ""
echo "Commands:"
echo "  ./monitor.sh                  # Watch live logs"
echo "  ./monitor.sh --status         # Check status"
echo "  ./stop-loop.sh                # Stop loop process (daemon may restart)"
echo "  ./stop-loop.sh --pause-daemon # Pause daemon (no auto-restart)"
echo "  ./stop-loop.sh --resume-daemon# Resume daemon"
echo "  ./install-daemon.sh --uninstall # Remove daemon completely"
