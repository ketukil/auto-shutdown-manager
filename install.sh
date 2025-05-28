#!/bin/bash

# Installation Script for Auto Shutdown Management System
# Usage: sudo ./install.sh [install|uninstall|status]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-install}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root or with sudo"
        echo "Usage: sudo $0 [install|uninstall|status]"
        exit 1
    fi
}

# Check if required files exist
check_files() {
    local missing_files=()
    
    for file in "auto-shutdown-manager.sh" "auto-shutdown-manager.service" "auto-shutdown-manager.timer"; do
        if [ ! -f "$SCRIPT_DIR/$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "Missing required files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        echo ""
        echo "Please ensure all files are in the same directory as this installer:"
        echo "  - auto-shutdown-manager.sh (main script)"
        echo "  - auto-shutdown-manager.service (systemd service)"
        echo "  - auto-shutdown-manager.timer (systemd timer)"
        echo "  - install.sh (this installer)"
        exit 1
    fi
}

# Create systemd service file
create_service_file() {
    cat > /etc/systemd/system/auto-shutdown-manager.service << 'EOF'
[Unit]
Description=Auto Shutdown Manager
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/auto-shutdown-manager.sh
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
}

# Create systemd timer file
create_timer_file() {
    cat > /etc/systemd/system/auto-shutdown-manager.timer << 'EOF'
[Unit]
Description=Auto Shutdown Manager Timer
Requires=auto-shutdown-manager.service

[Timer]
OnCalendar=*:*/5
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

# Install function
install_system() {
    log_info "Installing Auto Shutdown Management System..."
    
    # Check for required files
    check_files
    
    # Create directories
    log_info "Creating directories..."
    mkdir -p /usr/local/bin
    mkdir -p /var/log
    
    # Install main script
    log_info "Installing main script..."
    cp "$SCRIPT_DIR/auto-shutdown-manager.sh" /usr/local/bin/auto-shutdown-manager.sh
    chmod +x /usr/local/bin/auto-shutdown-manager.sh
    
    # Install systemd files
    log_info "Installing systemd service..."
    if [ -f "$SCRIPT_DIR/auto-shutdown-manager.service" ]; then
        cp "$SCRIPT_DIR/auto-shutdown-manager.service" /etc/systemd/system/
    else
        create_service_file
    fi
    
    log_info "Installing systemd timer..."
    if [ -f "$SCRIPT_DIR/auto-shutdown-manager.timer" ]; then
        cp "$SCRIPT_DIR/auto-shutdown-manager.timer" /etc/systemd/system/
    else
        create_timer_file
    fi
    
    # Set proper permissions
    chmod 644 /etc/systemd/system/auto-shutdown-manager.service
    chmod 644 /etc/systemd/system/auto-shutdown-manager.timer
    
    # Create log file
    log_info "Creating log file..."
    touch /var/log/auto-shutdown.log
    chmod 644 /var/log/auto-shutdown.log
    
    # Reload systemd
    log_info "Reloading systemd..."
    systemctl daemon-reload
    
    log_success "Installation completed successfully!"
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Enable the service:    sudo systemctl enable auto-shutdown-manager.timer"
    echo "  2. Start the service:     sudo systemctl start auto-shutdown-manager.timer"
    echo "  3. Check status:          sudo systemctl status auto-shutdown-manager.timer"
    echo "  4. View logs:             tail -f /var/log/auto-shutdown.log"
    echo ""
    echo "🛡️  Override Commands:"
    echo "  Disable auto-shutdown:    touch ~/.company_will_pay_for_it"
    echo "  Enable auto-shutdown:     rm ~/.company_will_pay_for_it"
    echo ""
    
    # Ask if user wants to enable now
    read -p "Do you want to enable and start the auto-shutdown service now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        enable_service
    fi
}

# Enable service function
enable_service() {
    log_info "Enabling and starting auto-shutdown service..."
    systemctl enable auto-shutdown-manager.timer
    systemctl start auto-shutdown-manager.timer
    log_success "Auto-shutdown service enabled and started!"
    
    # Show status
    echo ""
    log_info "Service Status:"
    systemctl status auto-shutdown-manager.timer --no-pager || true
}

# Uninstall function
uninstall_system() {
    log_info "Uninstalling Auto Shutdown Management System..."
    
    # Stop and disable service
    log_info "Stopping and disabling service..."
    systemctl stop auto-shutdown-manager.timer 2>/dev/null || true
    systemctl disable auto-shutdown-manager.timer 2>/dev/null || true
    
    # Remove files
    log_info "Removing files..."
    rm -f /usr/local/bin/auto-shutdown-manager.sh
    rm -f /etc/systemd/system/auto-shutdown-manager.service
    rm -f /etc/systemd/system/auto-shutdown-manager.timer
    
    # Clean up state files
    rm -f /tmp/auto-shutdown-state
    
    # Reload systemd
    log_info "Reloading systemd..."
    systemctl daemon-reload
    
    log_success "Uninstallation completed!"
    echo ""
    log_warning "Log file preserved at: /var/log/auto-shutdown.log"
    echo "Remove manually if desired: sudo rm /var/log/auto-shutdown.log"
}

# Status function
show_status() {
    echo "📊 Auto Shutdown Management System Status"
    echo "=========================================="
    echo ""
    
    # Check if files exist
    log_info "Checking installation..."
    if [ -f "/usr/local/bin/auto-shutdown-manager.sh" ]; then
        log_success "Main script installed"
    else
        log_error "Main script not found"
    fi
    
    if [ -f "/etc/systemd/system/auto-shutdown-manager.service" ]; then
        log_success "Systemd service installed"
    else
        log_error "Systemd service not found"
    fi
    
    if [ -f "/etc/systemd/system/auto-shutdown-manager.timer" ]; then
        log_success "Systemd timer installed"
    else
        log_error "Systemd timer not found"
    fi
    
    echo ""
    log_info "Service Status:"
    systemctl status auto-shutdown-manager.timer --no-pager 2>/dev/null || log_warning "Service not running"
    
    echo ""
    log_info "Timer Status:"
    systemctl list-timers auto-shutdown-manager.timer --no-pager 2>/dev/null || log_warning "Timer not found"
    
    echo ""
    log_info "Recent Logs (last 10 lines):"
    if [ -f "/var/log/auto-shutdown.log" ]; then
        tail -n 10 /var/log/auto-shutdown.log
    else
        log_warning "Log file not found"
    fi
    
    echo ""
    log_info "Override Status:"
    if [ -f "$HOME/.company_will_pay_for_it" ]; then
        log_warning "Override ACTIVE - Auto-shutdown is DISABLED"
    else
        log_success "Override inactive - Auto-shutdown is ENABLED"
    fi
}

# Test function
run_test() {
    log_info "Running manual test..."
    if [ -f "/usr/local/bin/auto-shutdown-manager.sh" ]; then
        /usr/local/bin/auto-shutdown-manager.sh
    else
        log_error "Script not installed. Run 'sudo $0 install' first."
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "Auto Shutdown Management System Installer"
    echo "=========================================="
    echo ""
    echo "Usage: sudo $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     - Install the auto shutdown system (default)"
    echo "  uninstall   - Remove the auto shutdown system"
    echo "  status      - Show installation and service status"
    echo "  test        - Run a manual test of the script"
    echo "  enable      - Enable and start the service"
    echo "  disable     - Stop and disable the service"
    echo ""
    echo "Examples:"
    echo "  sudo $0 install    # Install and optionally enable"
    echo "  sudo $0 status     # Check current status"
    echo "  sudo $0 test       # Test the script manually"
    echo "  sudo $0 uninstall  # Remove everything"
}

# Main execution
main() {
    case "$ACTION" in
        "install")
            check_root
            install_system
            ;;
        "uninstall")
            check_root
            uninstall_system
            ;;
        "status")
            show_status
            ;;
        "test")
            check_root
            run_test
            ;;
        "enable")
            check_root
            enable_service
            ;;
        "disable")
            check_root
            log_info "Disabling auto-shutdown service..."
            systemctl stop auto-shutdown-manager.timer
            systemctl disable auto-shutdown-manager.timer
            log_success "Auto-shutdown service disabled!"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            log_error "Unknown command: $ACTION"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main