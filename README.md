# NetCheck

A macOS menu-bar application for monitoring network availability across multiple networks.

## Features

- **Multi-network monitoring** - Monitor multiple networks with a single unified tray icon
- **Multiple protocol support** - ICMP, TCP, DNS, HTTP, HTTPS, SSH
- **Visual status indicators** - Color-coded status (green/yellow/red/gray)
- **Adaptive icon display** - Circular sectors for 1-6 networks, horizontal lines for 7+
- **Inline configuration** - Edit networks and checks in a single window
- **Automatic periodic checks** - Configurable check intervals (5-300 seconds)
- **Configuration persistence** - Automatic save to JSON, restores state on launch
- **Keyboard shortcuts** - Escape=Cancel, Enter=Save
- **Clipboard support** - Command-C/Command-V in text fields

## Requirements

- macOS 13.0 or later
- Swift 6.3

## Installation

### Option 1: Download Binary (Recommended)

1. Download the latest release from [GitHub Releases](https://github.com/archergodson/netcheck/releases)
2. Extract the archive
3. Move `NetCheck.app` to `/Applications`
4. Double-click to launch, or run from Terminal:
   ```bash
   open /Applications/NetCheck.app
   ```

### Option 2: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/archergodson/netcheck.git
   cd netcheck
   ```

2. Build the application:
   ```bash
   swift build
   ```

3. Run the application:
   ```bash
   ./.build/debug/NetCheck
   ```

4. Run with verbose logging:
   ```bash
   ./.build/debug/NetCheck -v
   # or
   ./.build/debug/NetCheck --verbose
   ```

### Option 3: Use Build Script

1. Clone the repository:
   ```bash
   git clone https://github.com/archergodson/netcheck.git
   cd netcheck
   ```

2. Run the build script:
   ```bash
   ./build.sh
   ```

3. Move the resulting `NetCheck.app` to `/Applications`

## Usage

1. NetCheck will appear in your menu bar with a single icon showing network statuses
2. Click the icon to see status details for each network
3. Click "Configure Networks..." to add/edit networks and checks
4. Each network can have multiple checks with different protocols and parameters

## Configuration

### Supported Check Types

- **ICMP** - Ping check to verify host reachability
- **TCP** - TCP port check (custom port)
- **DNS** - DNS resolution check (optional custom DNS server)
- **HTTP** - HTTP check (default port 80)
- **HTTPS** - HTTPS check (port 443)
- **SSH** - SSH check (port 22)

### Status Colors

- 🟢 **Green** - All checks available
- 🟡 **Yellow** - Some checks available
- 🔴 **Red** - All checks unavailable
- ⚪ **Gray** - Not checked yet
- 🟢🟡🔴 **Muted colors** - Same status with pending checks

## Configuration File

Configuration is stored in:
```
~/Library/Application Support/NetCheck/config.json
```

You can manually edit this file, but it's recommended to use the built-in configuration window.

## Keyboard Shortcuts

- **Escape** - Cancel/Close without saving
- **Enter** - Save changes
- **Command-C/Command-V** - Copy/Paste in text fields

## Development

### Building

```bash
swift build
```

### Running

```bash
./.build/debug/NetCheck
```

### Clean Build

```bash
swift package clean
swift build
```

## Version History

- **v1.2.0** - Extended circular sectors to 6 networks, horizontal lines for 7+
- **v1.1.0** - Circular sector division for network status display
- **v1.0.0** - First stable release

## License

[Add your license here, e.g., MIT License]

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues or questions, please open an issue on GitHub.
