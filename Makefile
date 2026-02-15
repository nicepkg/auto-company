.PHONY: start start-awake awake stop status last cycles monitor pause resume install uninstall team cycle-005-evidence cycle-005-preflight cycle-005-preflight-enable-autorun cycle-005-env-sync help

# === Quick Start ===

start: ## Start the auto-loop in foreground
	./auto-loop.sh

start-awake: ## Start loop and inhibit sleep while running (macOS/Linux)
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		caffeinate -d -i -s $(MAKE) start; \
	elif [ "$$(uname -s)" = "Linux" ] && command -v systemd-inhibit >/dev/null 2>&1; then \
		systemd-inhibit --what=sleep --why="Auto Company loop" $(MAKE) start; \
	else \
		echo "Sleep inhibition helper not available; starting normally."; \
		$(MAKE) start; \
	fi

awake: ## Inhibit sleep while current loop PID is running (macOS/Linux)
	@test -f .auto-loop.pid || (echo "No .auto-loop.pid found. Run 'make start' first."; exit 1)
	@pid=$$(cat .auto-loop.pid); \
	if [ "$$(uname -s)" = "Darwin" ]; then \
		echo "Keeping macOS awake while PID $$pid is running..."; \
		caffeinate -d -i -s -w $$pid; \
	elif [ "$$(uname -s)" = "Linux" ] && command -v systemd-inhibit >/dev/null 2>&1; then \
		echo "Inhibiting Linux sleep while PID $$pid is running..."; \
		systemd-inhibit --what=sleep --why="Auto Company loop PID $$pid" bash -lc "while kill -0 $$pid 2>/dev/null; do sleep 5; done"; \
	else \
		echo "Sleep inhibition helper not available on this OS."; \
		exit 1; \
	fi

stop: ## Stop the loop gracefully
	./stop-loop.sh

# === Monitoring ===

status: ## Show loop status + latest consensus
	./monitor.sh --status

last: ## Show last cycle's full output
	./monitor.sh --last

cycles: ## Show cycle history summary
	./monitor.sh --cycles

monitor: ## Tail live logs (Ctrl+C to exit)
	./monitor.sh

# === Daemon (launchd/systemd) ===

install: ## Install daemon (auto-start + crash recovery)
	./install-daemon.sh

uninstall: ## Remove daemon
	./install-daemon.sh --uninstall

pause: ## Pause daemon (no auto-restart)
	./stop-loop.sh --pause-daemon

resume: ## Resume paused daemon
	./stop-loop.sh --resume-daemon

# === Interactive ===

team: ## Start interactive Codex session
	cd "$(CURDIR)" && codex

# === Evidence Runs ===

cycle-005-evidence: ## Trigger Cycle 005 hosted persistence evidence workflow (requires gh auth + repo vars/secrets)
	./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh

cycle-005-preflight: ## Trigger Cycle 005 hosted preflight-only run (no evidence + no PR)
	./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --preflight-only

cycle-005-preflight-enable-autorun: ## Run preflight-only; if green, enable scheduled runs via CYCLE_005_AUTORUN_ENABLED=true
	./scripts/devops/run-cycle-005-hosted-persistence-evidence.sh --enable-autorun-after-preflight

cycle-005-env-sync: ## Sync hosted runtime env vars (Supabase) via provider API + redeploy (requires gh write perms + repo vars/secrets)
	./scripts/devops/run-cycle-005-hosted-runtime-env-sync.sh

# === Maintenance ===

clean-logs: ## Remove all cycle logs
	rm -f logs/cycle-*.log logs/auto-loop.log.old
	@echo "Cycle logs cleaned."

reset-consensus: ## Reset consensus to initial Day 0 state (CAUTION)
	@echo "This will reset all company progress. Ctrl+C to cancel."
	@sleep 3
	git checkout -- memories/consensus.md
	@echo "Consensus reset to initial state."

# === Help ===

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

.DEFAULT_GOAL := help
