import AppKit
import SwiftUI

@MainActor
class TrayIconManager: ObservableObject {
    private var statusItems: [UUID: NSStatusItem] = [:]
    private var menuManagers: [UUID: MenuManager] = [:]
    var onConfigure: (() -> Void)?
    var onRefresh: (() -> Void)?
    
    func updateTrayIcons(for networks: [NetworkCheck]) {
        // Remove networks that no longer exist
        let currentIds = Set(networks.map { $0.id })
        let removedIds = Set(statusItems.keys).subtracting(currentIds)
        
        for id in removedIds {
            if let statusItem = statusItems[id] {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
            statusItems.removeValue(forKey: id)
            menuManagers.removeValue(forKey: id)
        }
        
        // Update or create status items for each network
        for network in networks {
            updateOrCreateStatusItem(for: network)
        }
    }
    
    private func updateOrCreateStatusItem(for network: NetworkCheck) {
        if let statusItem = statusItems[network.id] {
            // Update existing status item
            updateStatusItem(statusItem, for: network)
            
            // Update menu manager callbacks
            if let menuManager = menuManagers[network.id] {
                menuManager.network = network
                menuManager.onConfigure = onConfigure
                menuManager.onRefresh = onRefresh
                statusItem.menu = menuManager.createMenu()
            }
        } else {
            // Create new status item
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusItems[network.id] = statusItem
            updateStatusItem(statusItem, for: network)
            
            // Create menu manager
            let menuManager = MenuManager(network: network)
            menuManager.onConfigure = onConfigure
            menuManager.onRefresh = onRefresh
            menuManagers[network.id] = menuManager
            statusItem.menu = menuManager.createMenu()
        }
    }
    
    private func updateStatusItem(_ statusItem: NSStatusItem, for network: NetworkCheck) {
        let icon = createIcon(for: network.status, name: network.name)
        if let button = statusItem.button {
            button.image = icon
            button.image?.isTemplate = false // Important: ensure image is not treated as template
            
            let lastCheckTime = network.lastCheck.map { 
                let formatter = DateFormatter()
                formatter.timeStyle = .medium
                return "Last check: \(formatter.string(from: $0))"
            } ?? "Not checked yet"
            
            button.toolTip = """
            \(network.name)
            Host: \(network.host)
            Status: \(statusString(for: network.status))
            \(lastCheckTime)
            """
        }
    }
    
    private func createIcon(for status: NetworkStatus, name: String) -> NSImage {
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.isTemplate = false
        
        // Create a new bitmap context for drawing
        guard let bitmap = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return image
        }
        
        // Draw the circle with status color
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        let path = CGPath(ellipseIn: rect, transform: nil)
        bitmap.addPath(path)
        
        let color = status.color
        bitmap.setFillColor(color.cgColor)
        bitmap.fillPath()
        
        // Draw first letter of network name
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        
        let firstLetter = String(name.first ?? "N")
        let letterSize = firstLetter.size(withAttributes: attributes)
        let letterRect = CGRect(
            x: (size.width - letterSize.width) / 2,
            y: (size.height - letterSize.height) / 2,
            width: letterSize.width,
            height: letterSize.height
        )
        
        firstLetter.draw(in: letterRect, withAttributes: attributes)
        
        // Create image from context
        if let cgImage = bitmap.makeImage() {
            return NSImage(cgImage: cgImage, size: size)
        }
        
        return image
    }
    
    private func statusString(for status: NetworkStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .partiallyAvailable:
            return "Partially Available"
        case .unavailable:
            return "Unavailable"
        }
    }
    
    func updateMenu(for network: NetworkCheck) {
        // Update the menu manager with new network data
        if let menuManager = menuManagers[network.id] {
            menuManager.network = network
            menuManager.onConfigure = onConfigure
            menuManager.onRefresh = onRefresh
            
            // Recreate the menu for the status item
            if let statusItem = statusItems[network.id] {
                statusItem.menu = menuManager.createMenu()
            }
        }
    }
    
    func refreshAllMenus(for networks: [NetworkCheck]) {
        for network in networks {
            updateMenu(for: network)
        }
    }
}

class MenuManager {
    var network: NetworkCheck
    var onConfigure: (() -> Void)?
    var onRefresh: (() -> Void)?
    
    init(network: NetworkCheck) {
        self.network = network
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Network name as title
        let titleItem = NSMenuItem(title: network.name, action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Host information with detailed description
        let hostItem = NSMenuItem(title: "Host: \(network.host)", action: nil, keyEquivalent: "")
        hostItem.isEnabled = false
        menu.addItem(hostItem)
        
        // Protocol information with detailed description
        let protocolItem = NSMenuItem(title: "Protocols: \(network.getProtocolDescription())", action: nil, keyEquivalent: "")
        protocolItem.isEnabled = false
        menu.addItem(protocolItem)
        
        // Status
        let statusItem = NSMenuItem(title: "Status: \(statusString())", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        
        // Last check time
        if let lastCheck = network.lastCheck {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
            let timeString = formatter.string(from: lastCheck)
            let timeItem = NSMenuItem(title: "Last check: \(timeString)", action: nil, keyEquivalent: "")
            timeItem.isEnabled = false
            menu.addItem(timeItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Protocol results with detailed information
        for protocolType in network.protocols {
            let result = network.protocolResults[protocolType] ?? false
            let status = result ? "✓" : "✗"
            
            var protocolDescription = ""
            switch protocolType {
            case .customTCP:
                if let port = network.customPort {
                    protocolDescription = "\(status) \(protocolType.rawValue) (\(port))"
                } else {
                    protocolDescription = "\(status) \(protocolType.rawValue)"
                }
            case .dns:
                // For DNS protocols, we can show more detailed information
                protocolDescription = "\(status) DNS lookup"
                if let port = network.customPort {
                    protocolDescription += " (port \(port))"
                }
            default:
                protocolDescription = "\(status) \(protocolType.rawValue)"
            }
            
            let protocolItem = NSMenuItem(title: protocolDescription, action: nil, keyEquivalent: "")
            protocolItem.isEnabled = false
            menu.addItem(protocolItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Configure button
        let configureItem = NSMenuItem(title: "Configure Networks...", action: #selector(configure), keyEquivalent: "")
        configureItem.target = self
        menu.addItem(configureItem)
        
        // Refresh button
        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit application
        let quitItem = NSMenuItem(title: "Quit NetCheck", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    private func statusString() -> String {
        switch network.status {
        case .available:
            return "Available"
        case .partiallyAvailable:
            return "Partially Available"
        case .unavailable:
            return "Unavailable"
        }
    }
    
    @MainActor @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    @objc private func configure() {
        onConfigure?()
    }
    
    @objc private func refresh() {
        onRefresh?()
    }
}