# NetCheck - Feature Specification

## Overview
NetCheck is a macOS tray application that monitors network availability for multiple networks using various protocols. Each network is represented by a tray icon with real-time status indicators.

## Core Functionality

### 1. Network Monitoring
- **Multiple Networks**: Support for monitoring multiple independent networks simultaneously
- **Individual Tray Icons**: Each network has its own tray icon in the macOS menu bar
- **Status Indicators**: Visual color-coded status for each network:
  - 🟢 Green: All checks available
  - 🟡 Yellow: Partially available (some checks failed)
  - 🔴 Red: All checks unavailable
  - ⚪ Gray: Not yet checked (initial state)

### 2. Check Types
Each network can contain multiple independent checks with the following types:

#### ICMP (Ping)
- **Purpose**: Basic connectivity check via ICMP protocol
- **Parameters**: Host (IP address or hostname)
- **Example**: `ICMP: 8.8.8.8`

#### TCP Port Check
- **Purpose**: Check if a specific TCP port is accessible
- **Parameters**: Host, Port (required)
- **Example**: `TCP: 192.168.1.1:80`

#### DNS Resolution
- **Purpose**: Check DNS resolution for a hostname
- **Parameters**: Host, DNS Server (optional)
- **Example**: `DNS: google.com` or `DNS: google.com via 8.8.8.8`

#### HTTP Check
- **Purpose**: Check HTTP server availability
- **Parameters**: Host, Port (optional, defaults to 80)
- **Example**: `HTTP: example.com:80`

#### HTTPS Check
- **Purpose**: Check HTTPS server availability
- **Parameters**: Host (port defaults to 443)
- **Example**: `HTTPS: example.com`

#### SSH Check
- **Purpose**: Check SSH server availability
- **Parameters**: Host (port defaults to 22)
- **Example**: `SSH: 192.168.1.1`

### 3. User Interface

#### Main Configuration Window
- **Split View Layout**: 
  - Left panel: Network list with names and status
  - Right panel: Selected network details and checks
- **Resizable Window**: Users can resize the configuration window
- **Minimum Size**: 800x600 pixels to ensure usability

#### Network Configuration
- **Network Name**: User-defined name for each network
- **Checks Management**: Add, edit, delete individual checks
- **Check Details**: Each check shows:
  - Type (ICMP, TCP, DNS, etc.)
  - Host address
  - Port (if applicable)
  - Status indicator
  - Description

#### Tray Icons
- **Icon Design**: Circle with first letter of network name
- **Color Coding**: Status-based color (green/yellow/red/gray)
- **Tooltip**: Shows network name, status, last check time, and available checks count
- **Menu Options**:
  - Network details
  - Individual check results
  - "Configure Networks..." option
  - "Refresh Now" option
  - "Quit NetCheck" option

### 4. Configuration Management

#### Check Interval
- **Range**: 5-300 seconds
- **Default**: 30 seconds
- **Location**: Available in main configuration window header

#### Configuration Persistence
- **Storage**: `~/Library/Application Support/NetCheck/config.json`
- **Format**: JSON
- **Auto-save**: Configuration saved automatically on changes
- **Migration**: Automatic migration from old config format if needed

### 5. Periodic Monitoring
- **Automatic Checks**: Networks are checked at configured intervals
- **Manual Refresh**: Users can trigger immediate checks via tray menu
- **Initial Check**: Application performs initial check on startup
- **Status Updates**: Tray icons and menus update after each check

## Technical Implementation

### Architecture
- **Network Entity**: Represents a logical network group (e.g., "Google", "Local Network")
- **Check Entity**: Represents an individual connectivity test with specific parameters
- **Separation of Concerns**: Networks contain multiple independent checks
- **Actor Pattern**: NetworkMonitor uses Swift actors for thread-safe network operations

### Network Monitoring Implementation
- **ICMP**: Uses `/sbin/ping` command
- **TCP**: Uses `/usr/bin/nc` (netcat) for port checks
- **DNS**: Uses `/usr/bin/dig` for DNS resolution
- **Timeout Handling**: Each check has appropriate timeout (2-5 seconds)
- **IP Address Handling**: DNS checks are skipped for IP addresses (considered as "DNS available")

### Status Calculation
- **Network Status**: Based on ratio of available checks to total checks
  - All checks available → Available (green)
  - Some checks available → Partially Available (yellow)
  - No checks available → Unavailable (red)
  - No checks performed → Not Checked (gray)
- **Check Status**: Binary (available/unavailable) with gray initial state

## Test Requirements

### Functional Tests
1. **Basic Functionality**
   - Application starts and creates tray icons
   - Configuration window opens correctly
   - Networks can be added, edited, and deleted
   - Checks can be added, edited, and deleted within networks

2. **Network Monitoring**
   - ICMP checks work for IP addresses and hostnames
   - TCP port checks work for specified ports
   - DNS resolution works for hostnames
   - DNS checks are skipped for IP addresses
   - HTTPS/SSH/HTTP checks work with correct ports

3. **Status Updates**
   - Tray icons update color based on network status
   - Tooltips show accurate information
   - Menus reflect current check results
   - Periodic checks update status automatically
   - Manual refresh works correctly

4. **Configuration**
   - Check interval changes are saved and applied
   - Configuration persists across application restarts
   - Invalid configurations are handled gracefully
   - Old configuration format migrates correctly

### UI/UX Tests
1. **Window Resizing**
   - Configuration window can be resized
   - Minimum size constraints are respected
   - Content remains usable at minimum size
   - Split view works correctly when resized

2. **Visual Feedback**
   - Status colors are correct (green/yellow/red/gray)
   - Icons display correctly in tray
   - Menu items are properly enabled/disabled
   - Tooltips are informative and accurate

### Edge Cases
1. **Network Failures**
   - Application handles network unavailability gracefully
   - Individual check failures don't crash the app
   - Timeout handling works correctly
   - Invalid hostnames are handled appropriately

2. **Configuration Errors**
   - Empty network names are rejected
   - Empty host addresses are rejected
   - Invalid port numbers are handled
   - Networks without checks cannot be saved

3. **Resource Management**
   - Memory usage remains stable over time
   - Network checks don't block the UI
   - Application responds to user input during checks
   - Tray icons are properly cleaned up on exit

## Performance Requirements
- **Check Completion**: Individual checks should complete within 5 seconds
- **UI Responsiveness**: Interface should remain responsive during network checks
- **Memory Usage**: Application should not leak memory over extended periods
- **CPU Usage**: Periodic checks should not significantly impact system performance

## Future Enhancements (Out of Scope)
- Custom check types
- Historical status tracking
- Notifications for status changes
- Export/import configuration
- Command-line interface
- System service mode
- Advanced timeout configuration per check

## Acceptance Criteria
1. ✅ Application runs in macOS menu bar without dock icon
2. ✅ Multiple networks can be configured with different checks
3. ✅ Each network has its own tray icon with status indicator
4. ✅ All check types (ICMP, TCP, DNS, HTTP, HTTPS, SSH) work correctly
5. ✅ Configuration window is resizable and usable
6. ✅ Status updates occur automatically at configured intervals
7. ✅ Manual refresh works correctly
8. ✅ Configuration persists across application restarts
9. ✅ Status colors are accurate and meaningful
10. ✅ Application handles network failures gracefully