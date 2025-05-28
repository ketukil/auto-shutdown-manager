# Makefile for Auto Shutdown Management System

# Installation directories
PREFIX ?= /usr/local
BINDIR = $(PREFIX)/bin
SYSTEMD_DIR = /etc/systemd/system
LOG_DIR = /var/log

# Base names
BASENAME = auto-shutdown-manager
SCRIPT = $(BASENAME).sh
SERVICE = $(BASENAME).service
TIMER = $(BASENAME).timer
LOG = auto-shutdown.log

# Full paths
SCRIPT_PATH = $(BINDIR)/$(SCRIPT)
SERVICE_PATH = $(SYSTEMD_DIR)/$(SERVICE)
TIMER_PATH = $(SYSTEMD_DIR)/$(TIMER)
LOG_PATH = $(LOG_DIR)/$(LOG)

.PHONY: help
help:
	@echo "Auto Shutdown Management System"
	@echo "================================"
	@echo ""
	@echo "Installation:"
	@echo "  install      - Install all files"
	@echo "  uninstall    - Remove all files"
	@echo ""
	@echo "Service Management:"
	@echo "  enable       - Enable and start the service"
	@echo "  disable      - Stop and disable the service"
	@echo "  start        - Start the service"
	@echo "  stop         - Stop the service"
	@echo "  restart      - Restart the service"
	@echo ""
	@echo "Monitoring:"
	@echo "  status       - Show service status"
	@echo "  logs         - Show recent logs"
	@echo "  test         - Run manual test"
	@echo ""
	@echo "Override Control:"
	@echo "  override-on  - Disable auto-shutdown"
	@echo "  override-off - Enable auto-shutdown"
	@echo ""
	@echo "Maintenance:"
	@echo "  clean        - Clean temporary files"
	@echo "  validate     - Validate files"
	@echo ""
	@echo "Note: Most targets require root privileges (use sudo)"

# Installation
.PHONY: install
install: check-root check-files
	@echo "🚀 Installing Auto Shutdown Management System..."
	@mkdir -p $(BINDIR) $(LOG_DIR)
	@install -m 755 $(SCRIPT) $(SCRIPT_PATH)
	@install -m 644 $(SERVICE) $(SERVICE_PATH)
	@install -m 644 $(TIMER) $(TIMER_PATH)
	@touch $(LOG_PATH)
	@chmod 644 $(LOG_PATH)
	@systemctl daemon-reload
	@echo "✅ Installation completed!"
	@echo ""
	@echo "Next: sudo make enable"

.PHONY: uninstall
uninstall: check-root
	@echo "🗑️ Uninstalling Auto Shutdown Management System..."
	-@systemctl stop $(TIMER) 2>/dev/null
	-@systemctl disable $(TIMER) 2>/dev/null
	@rm -f $(SCRIPT_PATH) $(SERVICE_PATH) $(TIMER_PATH)
	@systemctl daemon-reload
	@echo "✅ Uninstallation completed!"
	@echo "Log file preserved: $(LOG_PATH)"

# Service Management
.PHONY: enable
enable: check-root
	@echo "▶️ Enabling auto-shutdown service..."
	@systemctl enable $(TIMER)
	@systemctl start $(TIMER)
	@echo "✅ Service enabled and started!"

.PHONY: disable
disable: check-root
	@echo "⏸️ Disabling auto-shutdown service..."
	@systemctl stop $(TIMER)
	@systemctl disable $(TIMER)
	@echo "✅ Service disabled and stopped!"

.PHONY: start
start: check-root
	@systemctl start $(TIMER)
	@echo "✅ Service started!"

.PHONY: stop
stop: check-root
	@systemctl stop $(TIMER)
	@echo "✅ Service stopped!"

.PHONY: restart
restart: check-root
	@systemctl restart $(TIMER)
	@echo "✅ Service restarted!"

# Monitoring
.PHONY: status
status:
	@echo "📊 Service Status:"
	@systemctl status $(TIMER) --no-pager || true
	@echo ""
	@echo "📊 Next Runs:"
	@systemctl list-timers $(TIMER) --no-pager || true

.PHONY: logs
logs:
	@echo "📋 Application Logs (last 20 lines):"
	@echo "===================================="
	@if [ -f $(LOG_PATH) ]; then \
		tail -n 20 $(LOG_PATH); \
	else \
		echo "Log file not found: $(LOG_PATH)"; \
	fi
	@echo ""
	@echo "📋 System Logs (last 10 lines):"
	@echo "==============================="
	@journalctl -u $(SERVICE) --no-pager -n 10 || true

.PHONY: test
test: check-root
	@echo "🧪 Running manual test..."
	@$(SCRIPT_PATH)

# Override Control
.PHONY: override-on
override-on:
	@echo "🛡️ Enabling override (disabling auto-shutdown)..."
	@touch ~/.company_will_pay_for_it
	@echo "✅ Override enabled! Auto-shutdown disabled."

.PHONY: override-off
override-off:
	@echo "🔓 Disabling override (enabling auto-shutdown)..."
	@rm -f ~/.company_will_pay_for_it
	@echo "✅ Override disabled! Auto-shutdown enabled."

# Maintenance
.PHONY: clean
clean:
	@echo "🧹 Cleaning temporary files..."
	@rm -f /tmp/auto-shutdown-state
	@echo "✅ Temporary files cleaned!"

.PHONY: validate
validate: check-files
	@echo "🔍 Validating script syntax..."
	@bash -n $(SCRIPT) && echo "✅ Script syntax valid"
	@echo "🔍 Validating systemd files..."
	@systemd-analyze verify $(SERVICE) $(TIMER) && echo "✅ Systemd files valid"

# Helper targets
.PHONY: check-root
check-root:
	@if [ "$$(id -u)" -ne 0 ]; then \
		echo "❌ This target requires root privileges. Please run with sudo."; \
		exit 1; \
	fi

.PHONY: check-files
check-files:
	@echo "🔍 Checking required files..."
	@for file in $(SCRIPT) $(SERVICE) $(TIMER); do \
		if [ ! -f "$$file" ]; then \
			echo "❌ Missing required file: $$file"; \
			exit 1; \
		fi; \
	done
	@echo "✅ All required files found"

# Development targets
.PHONY: dev-install
dev-install: validate install enable
	@echo "🚀 Development installation completed!"

# Default target
.DEFAULT_GOAL := help