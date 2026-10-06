import AppKit
import SwiftUI

@main
struct NetCheck {
    static func main() {
        let args = CommandLine.arguments
        let verbose = args.contains("-v") || args.contains("--verbose")
        
        let app = NSApplication.shared
        let delegate = AppDelegate(verbose: verbose)
        app.delegate = delegate
        app.run()
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var trayIconManager = TrayIconManager()
    private var config: AppConfig
    private var timer: Timer?
    private let verbose: Bool
    
    init(verbose: Bool = false) {
        self.verbose = verbose
        self.config = ConfigManager.shared.loadConfig()
        super.init()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up the app to run as a background app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Set up tray icon callbacks
        trayIconManager.onConfigure = { [weak self] in
            self?.showConfigWindow()
        }
        trayIconManager.onRefresh = { [weak self] in
            Task {
                await self?.performNetworkChecks()
            }
        }
        
        // Create default configuration if empty
        if config.networks.isEmpty {
            createDefaultConfiguration()
        }
        
        logVerbose("Application launched with \(config.networks.count) networks")
        for network in config.networks {
            logVerbose("  - \(network.name) (\(network.checks.count) checks)")
        }
        
        // Update tray icons
        trayIconManager.updateTrayIcons(for: config.networks)
        
        // Start periodic checks
        startPeriodicChecks()
        
        // Initial check
        Task {
            await performNetworkChecks()
        }
    }
    
    private func createDefaultConfiguration() {
        log("Creating default configuration")
        let googleNetwork = Network(name: "Google", checks: [
            NetworkCheck(type: .icmp, host: "8.8.8.8"),
            NetworkCheck(type: .dns, host: "google.com")
        ])
        
        let localNetwork = Network(name: "Local Router", checks: [
            NetworkCheck(type: .icmp, host: "192.168.1.1"),
            NetworkCheck(type: .tcp, host: "192.168.1.1", port: 80)
        ])
        
        config.networks = [googleNetwork, localNetwork]
        Task {
            await ConfigManager.shared.saveConfig(config)
        }
    }
    
    private func startPeriodicChecks() {
        timer = Timer.scheduledTimer(withTimeInterval: config.checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performNetworkChecks()
            }
        }
    }
    
    private func performNetworkChecks() async {
        var updatedNetworks: [Network] = []
        
        for network in config.networks {
            let previousStatus = network.status
            let updatedNetwork = await NetworkMonitor.shared.checkNetwork(network)
            updatedNetworks.append(updatedNetwork)
            
            if previousStatus != updatedNetwork.status {
                log("Network '\(network.name)' status changed: \(previousStatus) -> \(updatedNetwork.status)")
            }
        }
        
        config.networks = updatedNetworks
        // Don't save config here - it would overwrite user's configuration
        // Statuses are dynamic and should be recalculated on each launch
        
        await MainActor.run {
            // Update tray icon and menu with all networks
            trayIconManager.updateTrayIcons(for: config.networks)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
    
    private func showConfigWindow() {
        let configWindow = ConfigWindow(config: config, verbose: verbose) { [weak self] updatedConfig in
            guard let self = self else { return }
            
            let previousNetworks = self.config.networks.map { $0.name }
            let newNetworks = updatedConfig.networks.map { $0.name }
            
            if previousNetworks != newNetworks {
                log("Configuration changed: networks list updated")
            }
            
            self.config = updatedConfig
            
            // Update tray icon with new configuration
            self.trayIconManager.updateTrayIcons(for: updatedConfig.networks)
            
            // Restart timer with new interval
            self.timer?.invalidate()
            self.startPeriodicChecks()
            
            // Perform immediate check to update status
            Task {
                await self.performNetworkChecks()
            }
        }
        
        configWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func log(_ message: String) {
        print("NetCheck: \(message)")
    }
    
    private func logVerbose(_ message: String) {
        if verbose {
            print("NetCheck [verbose]: \(message)")
        }
    }
}
