#!/bin/bash

# Auto Shutdown Management System
# /usr/local/bin/auto-shutdown-manager.sh

# Configuration constants
LOG_FILE="/var/log/auto-shutdown.log"
STATE_FILE="/tmp/auto-shutdown-state"
OVERRIDE_FILE="$HOME/.company_will_pay_for_it"
TIMEZONE="Europe/Zagreb"

# Time constants (in minutes from midnight)
readonly WORK_START_HOUR=8
readonly WORK_END_HOUR=11
readonly WORK_START_MINUTES=$((WORK_START_HOUR * 60))  # 8AM = 480 minutes
readonly WORK_END_MINUTES=$((WORK_END_HOUR * 60))      # 6PM = 1080 minutes

# Shutdown timer constants (in seconds)
readonly WEEKEND_SHUTDOWN_DELAY=300        # 5 minutes
readonly AFTER_HOURS_SHUTDOWN_DELAY=300    # 5 minutes
readonly WORK_HOURS_SHUTDOWN_DELAY=1800    # 30 minutes

# Warning interval constants (in seconds)
readonly AFTER_HOURS_WARNING_INTERVAL=300  # 5 minutes
readonly OVERRIDE_WARNING_INTERVAL=900     # 15 minutes

# Day of week constants
readonly MONDAY=1
readonly TUESDAY=2
readonly WEDNESDAY=3
readonly THURSDAY=4
readonly FRIDAY=5
readonly SATURDAY=6
readonly SUNDAY=7

# Session counting constants
readonly DEFAULT_SESSION_COUNT=0
readonly DEFAULT_TIMER_VALUE=0
readonly DEFAULT_WARNING_TIME=0

# Shutdown delay constants
readonly SHUTDOWN_GRACE_PERIOD=5           # 5 seconds before actual shutdown
readonly TIMER_PRECISION=59                # For rounding minutes calculation

# Logging function
log_message() {
    echo "$(TZ=$TIMEZONE date '+%Y-%m-%d %H:%M:%S %Z'): $1" >> "$LOG_FILE"
}

# Function to get active sessions count
get_active_sessions() {
    local count=0
    
    # Count SSH/TTY sessions
    local ssh_count
    ssh_count=$(who | grep -E 'pts/|tty' | wc -l 2>/dev/null || echo $DEFAULT_SESSION_COUNT)
    ssh_count=$(echo "$ssh_count" | tr -d '\n\r ')
    if [[ "$ssh_count" =~ ^[0-9]+$ ]]; then
        count=$((count + ssh_count))
    fi
    
    # Count screen sessions
    local screen_count
    screen_count=$(screen -ls 2>/dev/null | grep -c "Attached\|Detached" 2>/dev/null || echo $DEFAULT_SESSION_COUNT)
    screen_count=$(echo "$screen_count" | tr -d '\n\r ')
    if [[ "$screen_count" =~ ^[0-9]+$ ]]; then
        count=$((count + screen_count))
    fi
    
    # Count tmux sessions
    local tmux_count
    tmux_count=$(tmux list-sessions 2>/dev/null | wc -l 2>/dev/null || echo $DEFAULT_SESSION_COUNT)
    tmux_count=$(echo "$tmux_count" | tr -d '\n\r ')
    if [[ "$tmux_count" =~ ^[0-9]+$ ]]; then
        count=$((count + tmux_count))
    fi
    
    echo "$count"
}

# Function to log session details
log_sessions() {
    # Log SSH sessions
    who | grep -E 'pts/|tty' | while read line; do
        log_message "SSH/TTY: $line"
    done
    
    # Log screen sessions
    screen -ls 2>/dev/null | grep -E "Attached|Detached" | while read line; do
        log_message "Screen: $line"
    done 2>/dev/null || true
    
    # Log tmux sessions
    tmux list-sessions 2>/dev/null | while read line; do
        log_message "Tmux: $line"
    done 2>/dev/null || true
}

# Function to send notifications
notify_users() {
    local message="$1"
    echo "$message" | wall 2>/dev/null || true
    log_message "NOTICE: $message"
}

# Function to check override
check_override() {
    [ -f "$OVERRIDE_FILE" ]
}

# Function to manage state
manage_state() {
    local action="$1"
    local value="$2"
    
    case "$action" in
        "set_timer")
            echo "shutdown_timer=$value" > "$STATE_FILE"
            echo "last_warning=$DEFAULT_WARNING_TIME" >> "$STATE_FILE"
            ;;
        "reset")
            rm -f "$STATE_FILE"
            ;;
        "get_timer")
            if [ -f "$STATE_FILE" ]; then
                local timer_val
                timer_val=$(grep "shutdown_timer=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2 || echo "$DEFAULT_TIMER_VALUE")
                timer_val=$(echo "$timer_val" | tr -d '\n\r ')
                if [[ "$timer_val" =~ ^[0-9]+$ ]]; then
                    echo "$timer_val"
                else
                    echo "$DEFAULT_TIMER_VALUE"
                fi
            else
                echo "$DEFAULT_TIMER_VALUE"
            fi
            ;;
        "get_last_warning")
            if [ -f "$STATE_FILE" ]; then
                local warning_val
                warning_val=$(grep "last_warning=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2 || echo "$DEFAULT_WARNING_TIME")
                warning_val=$(echo "$warning_val" | tr -d '\n\r ')
                if [[ "$warning_val" =~ ^[0-9]+$ ]]; then
                    echo "$warning_val"
                else
                    echo "$DEFAULT_WARNING_TIME"
                fi
            else
                echo "$DEFAULT_WARNING_TIME"
            fi
            ;;
        "set_last_warning")
            if [ -f "$STATE_FILE" ]; then
                sed -i "s/last_warning=.*/last_warning=$value/" "$STATE_FILE"
            fi
            ;;
    esac
}

# Main function
main() {
    log_message "=== Auto-shutdown check started ==="
    
    # Get current time info
    export TZ=$TIMEZONE
    local current_hour=$(date +%H)
    local current_minute=$(date +%M)
    local day_of_week=$(date +%u)
    local current_time=$(date '+%H:%M')
    local current_time_minutes=$((current_hour * 60 + current_minute))
    local current_epoch=$(date +%s)
    
    # Check if weekend
    local is_weekend=0
    if [ "$day_of_week" -eq "$SATURDAY" ] || [ "$day_of_week" -eq "$SUNDAY" ]; then
        is_weekend=1
    fi
    
    local day_type="Weekday"
    if [ "$is_weekend" -eq 1 ]; then
        day_type="Weekend"
    fi
    
    log_message "Time: $current_time, Day: $day_of_week ($day_type)"
    
    # Get active sessions
    local active_sessions
    active_sessions=$(get_active_sessions)
    active_sessions=$(echo "$active_sessions" | tr -d '\n\r ')
    
    # Validate it's a number
    if ! [[ "$active_sessions" =~ ^[0-9]+$ ]]; then
        active_sessions=$DEFAULT_SESSION_COUNT
        log_message "WARNING: Could not determine session count, assuming $DEFAULT_SESSION_COUNT"
    fi
    
    log_sessions
    log_message "Active sessions: $active_sessions"
    
    # Check for override
    if check_override; then
        # Check for override
        local last_warning
        last_warning=$(manage_state "get_last_warning")
        last_warning=$(echo "$last_warning" | tr -d '\n\r ')
        if ! [[ "$last_warning" =~ ^[0-9]+$ ]]; then
            last_warning=$DEFAULT_WARNING_TIME
        fi
        local time_diff=$((current_epoch - last_warning))
        
        # Warn every 15 minutes after 6pm
        if [ "$current_time_minutes" -ge "$WORK_END_MINUTES" ] && [ "$time_diff" -ge "$OVERRIDE_WARNING_INTERVAL" ]; then
            notify_users "Override active - auto-shutdown disabled. Remove $OVERRIDE_FILE to re-enable."
            manage_state "set_last_warning" "$current_epoch"
        fi
        
        manage_state "reset"
        log_message "Auto-shutdown disabled by override file"
        return 0
    fi
    
    local shutdown_timer
    shutdown_timer=$(manage_state "get_timer")
    shutdown_timer=$(echo "$shutdown_timer" | tr -d '\n\r ')
    if ! [[ "$shutdown_timer" =~ ^[0-9]+$ ]]; then
        shutdown_timer=$DEFAULT_TIMER_VALUE
    fi
    
    # Weekend logic
    if [ "$is_weekend" -eq 1 ]; then
        log_message "Weekend mode"
        
        if [ "$active_sessions" -eq "$DEFAULT_SESSION_COUNT" ]; then
            if [ "$shutdown_timer" -eq "$DEFAULT_TIMER_VALUE" ]; then
                # Start 5-minute timer
                local shutdown_time=$((current_epoch + WEEKEND_SHUTDOWN_DELAY))
                manage_state "set_timer" "$shutdown_time"
                notify_users "Weekend: No users detected. Shutdown in $((WEEKEND_SHUTDOWN_DELAY / 60)) minutes."
                log_message "Weekend shutdown timer started ($((WEEKEND_SHUTDOWN_DELAY / 60)) min)"
            elif [ "$current_epoch" -ge "$shutdown_timer" ]; then
                # Execute shutdown
                notify_users "Weekend: Shutting down now."
                log_message "Weekend shutdown executed"
                sleep $SHUTDOWN_GRACE_PERIOD
                shutdown -h now "Weekend auto-shutdown"
            else
                local remaining=$(((shutdown_timer - current_epoch + TIMER_PRECISION) / 60))
                log_message "Weekend shutdown timer: $remaining minutes remaining"
            fi
        else
            if [ "$shutdown_timer" -gt "$DEFAULT_TIMER_VALUE" ]; then
                manage_state "reset"
                log_message "Weekend shutdown cancelled - users connected"
            fi
        fi
        return 0
    fi
    
    # Weekday logic
    log_message "Weekday mode"
    
    if [ "$current_time_minutes" -lt "$WORK_START_MINUTES" ] || [ "$current_time_minutes" -ge "$WORK_END_MINUTES" ]; then
        # Outside work hours
        log_message "Outside work hours"
        
        if [ "$active_sessions" -eq "$DEFAULT_SESSION_COUNT" ]; then
            if [ "$shutdown_timer" -eq "$DEFAULT_TIMER_VALUE" ]; then
                # Start 5-minute timer
                local shutdown_time=$((current_epoch + AFTER_HOURS_SHUTDOWN_DELAY))
                manage_state "set_timer" "$shutdown_time"
                notify_users "After hours: No users detected. Shutdown in $((AFTER_HOURS_SHUTDOWN_DELAY / 60)) minutes."
                log_message "After-hours shutdown timer started ($((AFTER_HOURS_SHUTDOWN_DELAY / 60)) min)"
            elif [ "$current_epoch" -ge "$shutdown_timer" ]; then
                # Execute shutdown
                notify_users "After hours: Shutting down now."
                log_message "After-hours shutdown executed"
                sleep $SHUTDOWN_GRACE_PERIOD
                shutdown -h now "After-hours auto-shutdown"
            fi
        else
            # Users connected after hours - warn every 5 minutes
            local last_warning
            last_warning=$(manage_state "get_last_warning")
            last_warning=$(echo "$last_warning" | tr -d '\n\r ')
            if ! [[ "$last_warning" =~ ^[0-9]+$ ]]; then
                last_warning=$DEFAULT_WARNING_TIME
            fi
            local time_diff=$((current_epoch - last_warning))
            

            if [ "$time_diff" -ge "$AFTER_HOURS_WARNING_INTERVAL" ] || [ "$last_warning" -eq "$DEFAULT_WARNING_TIME" ]; then
                notify_users "After $WORK_END_HOUR:00 Please finish work. Auto-shutdown will occur $((AFTER_HOURS_SHUTDOWN_DELAY / 60)) min after last disconnect."
                manage_state "set_last_warning" "$current_epoch"
                log_message "After-hours warning sent"
            fi
            
            if [ "$shutdown_timer" -gt "$DEFAULT_TIMER_VALUE" ]; then
                manage_state "reset"
                log_message "After-hours shutdown cancelled - users still connected"
            fi
        fi
    else
        # During work hours
        log_message "During work hours"
        
        if [ "$active_sessions" -eq "$DEFAULT_SESSION_COUNT" ]; then
            if [ "$shutdown_timer" -eq "$DEFAULT_TIMER_VALUE" ]; then
                # Start 30-minute timer
                local shutdown_time=$((current_epoch + WORK_HOURS_SHUTDOWN_DELAY))
                manage_state "set_timer" "$shutdown_time"
                notify_users "Work hours: No users detected. Shutdown in $((WORK_HOURS_SHUTDOWN_DELAY / 60)) minutes to save costs."
                log_message "Work-hours shutdown timer started ($((WORK_HOURS_SHUTDOWN_DELAY / 60)) min)"
            elif [ "$current_epoch" -ge "$shutdown_timer" ]; then
                # Execute shutdown
                notify_users "Work hours: Shutting down now to save costs."
                log_message "Work-hours shutdown executed"
                sleep $SHUTDOWN_GRACE_PERIOD
                shutdown -h now "Work-hours auto-shutdown"
            fi
        else
            if [ "$shutdown_timer" -gt "$DEFAULT_TIMER_VALUE" ]; then
                manage_state "reset"
                log_message "Work-hours shutdown cancelled - users connected"
            fi
        fi
    fi
    
    log_message "=== Auto-shutdown check completed ==="
}

# Create log file if it doesn't exist
touch "$LOG_FILE" 2>/dev/null || true
chmod 644 "$LOG_FILE" 2>/dev/null || true

# Run main function
main