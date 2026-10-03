import AppKit
import SwiftUI

@main
struct NetCheck {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    private var trayIconManager = TrayIconManager()
    private var config: AppConfig
    private var timer: Timer?
    
    override init() {
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
        
        print("Application launched with \(config.networks.count) networks")
        for network in config.networks {
            print("  - \(network.name) (\(network.checks.count) checks)")
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
            let updatedNetwork = await NetworkMonitor.shared.checkNetwork(network)
            updatedNetworks.append(updatedNetwork)
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
        let configWindow = ConfigWindow(config: config) { [weak self] updatedConfig in
            guard let self = self else { return }
            
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
}
