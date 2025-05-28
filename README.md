# Auto Shutdown Management System

Intelligent auto-shutdown system for Ubuntu servers that manages power based on user activity and work schedules, designed for cost optimization on cloud instances like AWS.

## Features

- **Smart Scheduling**: Different rules for weekdays vs weekends
- **User Activity Monitoring**: Tracks SSH, screen, tmux, and login sessions
- **Graceful Warnings**: Notifies users before shutdown
- **Override System**: Temporary disable with warning notifications
- **Comprehensive Logging**: Detailed activity logs for transparency
- **Systemd Integration**: Reliable service management
- **Professional Tooling**: Make-based installation and management

## Shutdown Rules

### Weekdays (Monday-Friday)

- **8AM-6PM**: Shutdown after 30 minutes if no users connected
- **After 6PM**: Warn users every 5 minutes, shutdown 5 minutes after last disconnect
- **Before 8AM**: Shutdown 5 minutes after last user disconnects

### Weekends (Saturday-Sunday)

- **Any time**: Shutdown 5 minutes after last user disconnects

### Override System

- Create `~/.company_will_pay_for_it` to disable auto-shutdown
- Warnings every 15 minutes after 6PM when override is active

## Quick Installation

### Method 1: Using the Installer (Recommended)

```bash
# Download all files to a directory
# Ensure you have: auto-shutdown-manager.sh, auto-shutdown-manager.service, 
#                  auto-shutdown-manager.timer, install.sh, Makefile

# Make installer executable and run
chmod +x install.sh
sudo ./install.sh install
```

### Method 2: Using Make (Professional)

```bash
# Ensure all files are present, then:
sudo make install
sudo make enable
```

## File Structure

```
auto-shutdown-system/
├── auto-shutdown-manager.sh      # Main script with intelligent logic
├── auto-shutdown-manager.service # Systemd service configuration
├── auto-shutdown-manager.timer   # Systemd timer (every 5 minutes)
├── install.sh                    # Interactive installer
├── Makefile                      # Professional build system
└── README.md                     # This documentation
```

## Management Commands

### Using Make (Recommended)

```bash
# Show all available commands
make help

# Installation
sudo make install        # Install all files
sudo make uninstall      # Remove everything

# Service Management  
sudo make enable         # Enable and start service
sudo make disable        # Stop and disable service
sudo make start          # Start service
sudo make stop           # Stop service
sudo make restart        # Restart service

# Monitoring
make status              # Show service status and next runs
make logs                # View recent logs
sudo make test           # Run manual test

# Override Control
make override-on         # Disable auto-shutdown
make override-off        # Enable auto-shutdown

# Maintenance
make clean              # Clean temporary files
make validate           # Validate script and systemd files
```

### Using the Install Script

```bash
# Installation options
sudo ./install.sh install     # Install with optional auto-enable
sudo ./install.sh uninstall   # Complete removal
./install.sh status           # Check installation status
sudo ./install.sh test        # Manual test run
sudo ./install.sh enable      # Enable service
sudo ./install.sh disable     # Disable service
```

### Direct systemd Commands

```bash
# Service control
sudo systemctl enable auto-shutdown-manager.timer
sudo systemctl start auto-shutdown-manager.timer
sudo systemctl stop auto-shutdown-manager.timer
sudo systemctl status auto-shutdown-manager.timer

# View logs
tail -f /var/log/auto-shutdown.log
journalctl -u auto-shutdown-manager.service -f
```

## Configuration

All timing constants are defined at the top of the script for easy customization:

### Work Hours

```bash
readonly WORK_START_HOUR=8        # 8 AM
readonly WORK_END_HOUR=18         # 6 PM
```

### Shutdown Delays

```bash
readonly WEEKEND_SHUTDOWN_DELAY=300        # 5 minutes
readonly AFTER_HOURS_SHUTDOWN_DELAY=300    # 5 minutes
readonly WORK_HOURS_SHUTDOWN_DELAY=1800    # 30 minutes
```

### Warning Intervals

```bash
readonly AFTER_HOURS_WARNING_INTERVAL=300  # 5 minutes
readonly OVERRIDE_WARNING_INTERVAL=900     # 15 minutes
```

### Check Frequency

Edit `/etc/systemd/system/auto-shutdown-manager.timer`:

```ini
# Current: every 5 minutes
OnCalendar=*:0/5

# Every minute:
OnCalendar=*:*

# Every 10 minutes:
OnCalendar=*:0/10
```

After changes: `sudo systemctl daemon-reload && sudo systemctl restart auto-shutdown-manager.timer`

### Timezone

The system uses `Europe/Zagreb` by default. To change:

```bash
# Set system timezone
sudo timedatectl set-timezone Your/Timezone

# Or edit the script constant
sudo nano /usr/local/bin/auto-shutdown-manager.sh
# Change: TIMEZONE="Europe/Zagreb"
```

## Session Monitoring

The system monitors these session types and logs their creation/destruction:

- **SSH sessions**: `who | grep pts`
- **Console sessions**: `who | grep tty`  
- **Screen sessions**: `screen -ls`
- **Tmux sessions**: `tmux list-sessions`
- **Login sessions**: `loginctl list-sessions`

## Troubleshooting

### Common Issues

1. **Timer not starting:**

   ```bash
   sudo systemctl status auto-shutdown-manager.timer
   # Check for calendar specification errors
   ```

2. **Script errors:**

   ```bash
   sudo make test           # Manual test
   make validate           # Check syntax
   ```

3. **Permission issues:**

   ```bash
   sudo make install       # Reinstall with proper permissions
   ```

4. **Timer format issues:**

   ```bash
   # Verify timer syntax
   systemd-analyze verify auto-shutdown-manager.timer
   ```

### Validation

```bash
# Validate everything
make validate

# Check specific components
bash -n auto-shutdown-manager.sh                    # Script syntax
systemd-analyze verify auto-shutdown-manager.timer  # Timer format
```

### Debug Mode

```bash
# Run with verbose output
sudo bash -x /usr/local/bin/auto-shutdown-manager.sh

# Monitor logs in real-time
tail -f /var/log/auto-shutdown.log

# Check systemd logs
journalctl -u auto-shutdown-manager.service -f
```

## Log Analysis

```bash
# Search for specific events
grep "shutdown timer" /var/log/auto-shutdown.log
grep "Active sessions" /var/log/auto-shutdown.log
grep "Weekend\|Weekday" /var/log/auto-shutdown.log

# Monitor in real-time with filtering
tail -f /var/log/auto-shutdown.log | grep -E "(timer|session|shutdown)"

# Recent activity summary
make logs
```

## Testing

### Test Scenarios

1. **Test Weekend Mode:**

   ```bash
   # Temporarily change date (careful!)
   sudo date -s "2024-12-07 14:00:00"  # Saturday 2PM
   sudo make test
   # Reset: sudo ntpdate -s time.nist.gov
   ```

2. **Test After Hours:**

   ```bash
   sudo date -s "2024-12-06 18:30:00"  # Friday 6:30PM
   sudo make test
   ```

3. **Test Override:**

   ```bash
   make override-on
   sudo make test  # Should show override message
   make override-off
   ```

### Development Testing

```bash
# Complete development workflow
make validate       # Check syntax and config
sudo make install   # Install files
sudo make enable    # Start service
make status         # Verify running
sudo make test      # Manual test
make logs          # Check output
```

## AWS Integration

### Cost Optimization

Typical savings for development/staging instances:

- **t3.medium**: ~$30/month → ~$10/month (67% savings)
- **t3.large**: ~$60/month → ~$20/month (67% savings)
- **m5.xlarge**: ~$140/month → ~$47/month (67% savings)

### Auto-Start Setup

Schedule instance start with AWS Lambda:

```python
import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    ec2.start_instances(InstanceIds=['i-1234567890abcdef0'])
```

### Instance Management

```bash
# Tag instances for auto-shutdown tracking
aws ec2 create-tags --resources i-1234567890abcdef0 --tags \
  Key=AutoShutdown,Value=Enabled \
  Key=Environment,Value=Development
```

## Security Features

- Runs as root (required for shutdown commands)
- Systemd security hardening enabled
- All actions logged with timestamps
- User-specific override files
- No network dependencies
- Read-only access to most system areas

## Uninstallation

### Complete Removal

```bash
# Using Make (recommended)
sudo make uninstall

# Using installer
sudo ./install.sh uninstall

# Manual cleanup
sudo systemctl stop auto-shutdown-manager.timer
sudo systemctl disable auto-shutdown-manager.timer
sudo rm -f /usr/local/bin/auto-shutdown-manager.sh
sudo rm -f /etc/systemd/system/auto-shutdown-manager.*
sudo rm -f /var/log/auto-shutdown.log
sudo rm -f /tmp/auto-shutdown-state
sudo systemctl daemon-reload
```

## Development

### Contributing

1. Fork the repository
2. Create feature branch: `git checkout -b feature-name`
3. Test thoroughly: `make validate && sudo make dev-install`
4. Commit changes: `git commit -am 'Add feature'`
5. Submit pull request

### Development Workflow

```bash
# Setup development environment
git clone https://github.com/your-repo/auto-shutdown-system.git
cd auto-shutdown-system

# Validate and install
make validate
sudo make dev-install

# Test changes
sudo make test
make logs

# Clean up for testing
make clean
```

## FAQ

### Q: Will this interfere with backups or scheduled jobs?

A: The system only shuts down when no users are connected. System services and cron jobs don't count as user sessions.

### Q: What happens if I'm downloading a large file?

A: As long as you maintain an SSH session, the system won't shut down.

### Q: Can I customize the timing?

A: Yes, edit the constants at the top of `/usr/local/bin/auto-shutdown-manager.sh`.

### Q: Does this work with other Linux distributions?  

A: Designed for Ubuntu but should work on any systemd-based distribution.

### Q: How do I temporarily disable for maintenance?

A: Use `make override-on` or `touch ~/.company_will_pay_for_it`.

### Q: Can I change the check frequency?

A: Yes, edit the timer file and use `sudo systemctl daemon-reload`.

## Support

- 📖 Documentation: This README and `make help`
- 🐛 Issues: Create GitHub issues for bugs
- 💬 Questions: Use GitHub discussions
- 📧 Contact: Check repository for contact information

## License

MIT License - see LICENSE file for details.

---

*Intelligent power management for cost-effective cloud computing.*

### Log Analysis

```bash
# Search for specific events
grep "shutdown timer" /var/log/auto-shutdown.log
grep "Active session" /var/log/auto-shutdown.log
grep "Weekend\|Weekday" /var/log/auto-shutdown.log

# Monitor in real-time
tail -f /var/log/auto-shutdown.log | grep -E "(timer|session|shutdown)"
```

## Testing

### Test Scenarios

1. **Test Weekend Mode:**

   ```bash
   # Temporarily change date (be careful!)
   sudo date -s "2024-12-07 14:00:00"  # Saturday 2PM
   sudo make test
   # Reset: sudo ntpdate -s time.nist.gov
   ```

2. **Test After Hours:**

   ```bash
   sudo date -s "2024-12-06 18:30:00"  # Friday 6:30PM
   sudo make test
   ```

3. **Test Override:**

   ```bash
   make override-on
   sudo make test
   # Should see override message
   make override-off
   ```

### Session Testing

The system monitors these session types:

- **SSH sessions**: `who | grep pts`
- **Console sessions**: `who | grep tty`
- **Screen sessions**: `screen -ls`
- **Tmux sessions**: `tmux list-sessions`
- **Login sessions**: `loginctl list-sessions`

## Security Features

- Runs as root (required for shutdown commands)
- Systemd security hardening enabled
- All actions logged with timestamps
- User-specific override files
- No network dependencies
- Read-only access to most system areas

## AWS Integration

### Cost Optimization

This system is particularly useful for development/staging AWS instances:

- **t3.medium**: ~$30/month → ~$10/month (67% savings)
- **t3.large**: ~$60/month → ~$20/month (67% savings)
- **m5.xlarge**: ~$140/month → ~$47/month (67% savings)

### Auto-Start Setup

To automatically start the instance when needed:

1. **Using AWS Lambda + CloudWatch Events:**

   ```python
   import boto3
   
   def lambda_handler(event, context):
       ec2 = boto3.client('ec2')
       ec2.start_instances(InstanceIds=['i-1234567890abcdef0'])
   ```

2. **Using AWS Systems Manager:**

   ```bash
   # Schedule instance start
   aws events put-rule --name "start-dev-instance" \
     --schedule-expression "cron(0 8 * * MON-FRI *)"
   ```

### Instance Tags

Add these tags for better management:

```bash
aws ec2 create-tags --resources i-1234567890abcdef0 --tags \
  Key=AutoShutdown,Value=Enabled \
  Key=Environment,Value=Development \
  Key=Project,Value=YourProject
```

## Advanced Configuration

### Custom Notification Methods

Extend the `notify_users()` function to add:

```bash
# Email notifications
notify_users() {
    local message="$1"
    echo "$message" | wall
    
    # Add email notification
    echo "$message" | mail -s "Server Auto-Shutdown Notice" admin@company.com
    
    # Add Slack notification
    curl -X POST -H 'Content-type: application/json' \
      --data '{"text":"'"$message"'"}' \
      YOUR_SLACK_WEBHOOK_URL
}
```

### Integration with Monitoring

Add monitoring integration:

```bash
# Add to the script
send_metrics() {
    local metric="$1"
    local value="$2"
    
    # CloudWatch metrics
    aws cloudwatch put-metric-data \
      --namespace "AutoShutdown" \
      --metric-data MetricName="$metric",Value="$value"
}
```

### Multiple Server Coordination

For managing multiple servers:

```bash
# Add server coordination
check_other_servers() {
    # Check if other critical servers are running
    local critical_servers=("server1.example.com" "server2.example.com")
    
    for server in "${critical_servers[@]}"; do
        if ping -c 1 "$server" &>/dev/null; then
            log_message "Critical server $server is online, delaying shutdown"
            return 1
        fi
    done
    return 0
}
```

## Uninstallation

### Complete Removal

```bash
# Using installer
sudo ./install.sh uninstall

# Using Makefile
sudo make uninstall

# Manual cleanup
sudo systemctl stop auto-shutdown-manager.timer
sudo systemctl disable auto-shutdown-manager.timer
sudo rm -f /usr/local/bin/auto-shutdown-manager.sh
sudo rm -f /etc/systemd/system/auto-shutdown-manager.*
sudo rm -f /var/log/auto-shutdown.log
sudo rm -f /tmp/auto-shutdown-state
sudo systemctl daemon-reload
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Test your changes thoroughly
4. Commit changes: `git commit -am 'Add feature'`
5. Push to branch: `git push origin feature-name`
6. Submit a pull request

### Development Setup

```bash
# Clone and setup
git clone https://github.com/your-repo/auto-shutdown-system.git
cd auto-shutdown-system

# Validate syntax
make validate

# Install for development
sudo make dev-install

# Test changes
sudo make test
```

## FAQ

### Q: Will this interfere with backups or scheduled jobs?

A: The system only shuts down when no users are connected and checks every 5 minutes. Most backup systems run as system services and won't be detected as user sessions. You can add custom logic to check for running backup processes.

### Q: What happens if I'm downloading a large file?

A: As long as you maintain an SSH session, the system won't shut down. The download will continue uninterrupted.

### Q: Can I customize the warning messages?

A: Yes, edit the `notify_users()` calls in `/usr/local/bin/auto-shutdown-manager.sh` to customize messages.

### Q: Does this work with other Linux distributions?

A: The script is designed for Ubuntu but should work on any systemd-based Linux distribution with minor modifications.

### Q: How do I temporary disable for maintenance?

A: Use `touch ~/.company_will_pay_for_it` or `make override-on`. The system will warn every 15 minutes after 6 PM but won't shut down.

### Q: Can I run this on multiple servers?

A: Yes, install on each server independently. Consider using configuration management tools like Ansible for large deployments.

## License

MIT License - see LICENSE file for details.

## Support

- 📧 Email: <admin@company.com>
- 🐛 Issues: GitHub Issues
- 📖 Documentation: This README
- 💬 Discussions: GitHub Discussions

## Changelog

### v1.0.0

- Initial release
- Basic weekday/weekend scheduling
- User session monitoring
- Override system
- Comprehensive logging
- Systemd integration
