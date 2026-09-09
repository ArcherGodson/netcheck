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
            print("  - \(network.name) (\(network.host))")
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
        let googleNetwork = NetworkCheck(
            name: "Google",
            host: "8.8.8.8",
            protocols: [.icmp, .dns]
        )
        
        let localNetwork = NetworkCheck(
            name: "Local Router",
            host: "192.168.1.1",
            protocols: [.icmp, .tcp],
            customPort: 80
        )
        
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
        var updatedNetworks: [NetworkCheck] = []
        
        for network in config.networks {
            let updatedNetwork = await NetworkMonitor.shared.checkNetwork(network)
            updatedNetworks.append(updatedNetwork)
        }
        
        config.networks = updatedNetworks
        await ConfigManager.shared.saveConfig(config)
        
        await MainActor.run {
            // Update tray icons and menus for all networks
            trayIconManager.updateTrayIcons(for: config.networks)
            trayIconManager.refreshAllMenus(for: config.networks)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }
    
    private func showConfigWindow() {
        let configWindow = ConfigWindow(config: config) { [weak self] updatedConfig in
            guard let self = self else { return }
            
            self.config = updatedConfig
            Task {
                await ConfigManager.shared.saveConfig(updatedConfig)
            }
            
            // Force update tray icons with new configuration
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
