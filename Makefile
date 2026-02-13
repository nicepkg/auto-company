.PHONY: start start-awake awake stop status last cycles monitor pause resume install uninstall team help

# === Quick Start ===

start: ## Start the auto-loop in foreground
	./auto-loop.sh

start-awake: ## Start loop and prevent macOS sleep while running
	caffeinate -d -i -s $(MAKE) start

awake: ## Prevent macOS sleep while current loop PID is running
	@test -f .auto-loop.pid || (echo "No .auto-loop.pid found. Run 'make start' first."; exit 1)
	@pid=$$(cat .auto-loop.pid); \
	echo "Keeping Mac awake while PID $$pid is running..."; \
	caffeinate -d -i -s -w $$pid

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

# === Daemon (launchd) ===

install: ## Install launchd daemon (auto-start + crash recovery)
	./install-daemon.sh

uninstall: ## Remove launchd daemon
	./install-daemon.sh --uninstall

pause: ## Pause daemon (no auto-restart)
	./stop-loop.sh --pause-daemon

resume: ## Resume paused daemon
	./stop-loop.sh --resume-daemon

# === Interactive ===

team: ## Start interactive Codex session
	cd "$(CURDIR)" && codex

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
