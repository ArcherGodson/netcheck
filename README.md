# NetCheck

A macOS tray application that monitors network availability for multiple hosts using various protocols.

## Features

- **Multiple Network Monitoring**: Monitor multiple networks/hosts simultaneously
- **Protocol Support**: 
  - ICMP (Ping)
  - DNS queries
  - TCP connections (with presets for SSH, HTTP, HTTPS)
  - Custom TCP ports
- **Visual Status Indicators**: 
  - 🟢 Green: All protocols available
  - 🟡 Yellow: Partially available
  - 🔴 Red: Network unavailable
- **Tray Icons**: Each network has its own tray icon with the first letter of the network name
- **Configurable Intervals**: Set custom check intervals (5-300 seconds)
- **Configuration UI**: Easy-to-use interface for managing networks
- **Real-time Updates**: Automatic periodic checks with manual refresh option

## Installation

1. Build the application:
```bash
swift build
```

2. Run the application:
```bash
./.build/debug/NetCheck
```

## Usage

### First Run

On first run, NetCheck creates a default configuration with two example networks:
- **Google**: 8.8.8.8 (ICMP + DNS)
- **Local Router**: 192.168.1.1 (ICMP + TCP port 80)

### Configuration

1. Click on any tray icon to see the network's status
2. Select "Configure Networks..." from the menu
3. In the configuration window:
   - Add new networks with the "+" button
   - Edit existing networks by clicking the pencil icon
   - Delete networks with the trash icon
   - Adjust the check interval
4. Click "Save" to apply changes

### Network Configuration

For each network, you can configure:
- **Name**: Display name (shown in tray icon tooltip)
- **Host**: Hostname or IP address to monitor
- **Protocols**: Select one or more protocols to check:
  - ICMP: Ping the host
  - DNS: Resolve DNS queries
  - TCP: Check TCP port availability
  - SSH: Check port 22
  - HTTP: Check port 80
  - HTTPS: Check port 443
  - Custom TCP: Specify a custom port
- **Custom Port**: Required when using Custom TCP protocol

### Tray Menu Options

Each network's tray menu provides:
- Network name and host
- Current status
- Last check time
- Individual protocol results
- "Configure Networks..." - Open configuration window
- "Refresh Now" - Immediate network check
- "Quit NetCheck" - Exit the application

## Configuration File

Configuration is stored in:
```
~/Library/Application Support/NetCheck/config.json
```

You can manually edit this file if needed, but using the configuration UI is recommended.

## Requirements

- macOS 13.0 or later
- Swift 6.0 or later

## Building from Source

```bash
# Clone or navigate to the project directory
cd NetCheck

# Build the project
swift build

# Run the application
./.build/debug/NetCheck
```

## Troubleshooting

### Application not appearing in menu bar
- Make sure the application is running
- Check that no other applications are hiding menu bar extras
- Try restarting the application

### Network checks failing
- Verify network connectivity
- Check that hostnames/IPs are correct
- Ensure firewalls allow the required protocols
- Try increasing the timeout values in NetworkMonitor.swift

### Configuration not saving
- Check write permissions for `~/Library/Application Support/NetCheck/`
- Ensure the directory exists

## Architecture

The application consists of several key components:

- **NetCheck.swift**: Main application delegate and setup
- **NetworkMonitor.swift**: Handles network connectivity checks using various protocols
- **TrayIconManager.swift**: Manages tray icons and menus
- **ConfigManager.swift**: Handles configuration persistence
- **ConfigWindow.swift**: SwiftUI configuration interface
- **Models.swift**: Data models for networks and configuration

## License

This project is provided as-is for educational and personal use.