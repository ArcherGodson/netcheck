import AppKit
import SwiftUI

@MainActor
class TrayIconManager: ObservableObject {
    private var statusItem: NSStatusItem?
    private var menuManager: UnifiedMenuManager?
    var onConfigure: (() -> Void)?
    var onRefresh: (() -> Void)?
    
    func updateTrayIcons(for networks: [Network]) {
        print("TrayIconManager: Updating single icon for \(networks.count) networks")
        for network in networks {
            print("TrayIconManager: - \(network.name) (id: \(network.id))")
        }
        
        // Create status item if it doesn't exist
        if statusItem == nil {
            print("TrayIconManager: Creating new status item")
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        }
        
        // Update the single icon with all network statuses
        if let statusItem = statusItem {
            let icon = createUnifiedIcon(for: networks)
            statusItem.button?.image = icon
            statusItem.button?.image?.isTemplate = false
            
            // Create unified menu manager
            menuManager = UnifiedMenuManager(networks: networks)
            menuManager?.onConfigure = onConfigure
            menuManager?.onRefresh = onRefresh
            statusItem.menu = menuManager?.createMenu()
            
            // Create tooltip with all network info
            var tooltipLines: [String] = []
            if networks.count <= 4 {
                // Show each network individually
                tooltipLines = networks.map { network in
                    let status = statusString(for: network.status)
                    let availableChecks = network.checks.filter { $0.status == .available }.count
                    let totalChecks = network.checks.count
                    return "\(network.name): \(status) (\(availableChecks)/\(totalChecks))"
                }
            } else {
                // Group by status
                var groupedNetworks: [NetworkStatus: [Network]] = [:]
                for network in networks {
                    groupedNetworks[network.status, default: []].append(network)
                }
                for (status, nets) in groupedNetworks {
                    let networkNames = nets.map { $0.name }.joined(separator: ", ")
                    let statusStr = statusString(for: status)
                    tooltipLines.append("\(statusStr): \(networkNames)")
                }
            }
            
            statusItem.button?.toolTip = tooltipLines.joined(separator: "\n")
        }
        
        print("TrayIconManager: Updated unified icon for \(networks.count) networks")
    }
    
    private func createUnifiedIcon(for networks: [Network]) -> NSImage {
        let size = NSSize(width: 32, height: 32)
        let image = NSImage(size: size)
        image.isTemplate = false
        
        // Determine display strategy
        if networks.count <= 4 {
            // Use circular sector division for 1-4 networks
            return createCircularIcon(for: networks, size: size)
        } else {
            // Group by status if more than 4 networks
            return createGroupedIcon(for: networks, size: size)
        }
    }
    
    private func createCircularIcon(for networks: [Network], size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.isTemplate = false
        
        let count = networks.count
        
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
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) / 2
        
        // Draw each network as a sector
        for (index, network) in networks.enumerated() {
            let startAngle: CGFloat
            let endAngle: CGFloat
            
            switch count {
            case 1:
                // Full circle
                startAngle = 0
                endAngle = 2 * .pi
            case 2:
                // Half circles (vertical split)
                startAngle = CGFloat(index) * .pi - .pi / 2
                endAngle = startAngle + .pi
            case 3:
                // 120° sectors
                startAngle = CGFloat(index) * (2 * .pi / 3) - .pi / 2
                endAngle = startAngle + (2 * .pi / 3)
            case 4:
                // 90° quadrants
                startAngle = CGFloat(index) * (.pi / 2) - .pi / 2
                endAngle = startAngle + (.pi / 2)
            default:
                startAngle = 0
                endAngle = 2 * .pi
            }
            
            // Draw sector
            let path = CGMutablePath()
            path.move(to: center)
            path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
            path.closeSubpath()
            
            let color = network.status.color
            bitmap.setFillColor(color.cgColor)
            bitmap.addPath(path)
            bitmap.fillPath()
            
            // Draw first letter of network name
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            
            let firstLetter = String(network.name.first ?? "N")
            let letterSize = firstLetter.size(withAttributes: attributes)
            
            // Calculate position in the middle of the sector
            let midAngle = (startAngle + endAngle) / 2
            let textRadius = radius * 0.5
            let textX = center.x + cos(midAngle) * textRadius - letterSize.width / 2
            let textY = center.y + sin(midAngle) * textRadius - letterSize.height / 2
            
            firstLetter.draw(at: CGPoint(x: textX, y: textY), withAttributes: attributes)
        }
        
        // Draw circular border
        let borderPath = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: size.width, height: size.height), transform: nil)
        bitmap.addPath(borderPath)
        bitmap.setStrokeColor(NSColor.black.cgColor)
        bitmap.setLineWidth(1.0)
        bitmap.strokePath()
        
        // Create image from context
        if let cgImage = bitmap.makeImage() {
            return NSImage(cgImage: cgImage, size: size)
        }
        
        return image
    }
    
    private func createGroupedIcon(for networks: [Network], size: NSSize) -> NSImage {
        let image = NSImage(size: size)
        image.isTemplate = false
        
        // Group networks by status
        var groupedNetworks: [NetworkStatus: [Network]] = [:]
        for network in networks {
            groupedNetworks[network.status, default: []].append(network)
        }
        
        let displayItems = Array(groupedNetworks)
        let count = displayItems.count
        
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
        
        // Calculate grid layout
        let gridSize = Int(ceil(sqrt(Double(count))))
        let cellWidth = size.width / CGFloat(gridSize)
        let cellHeight = size.height / CGFloat(gridSize)
        
        // Draw each status/group
        for (index, item) in displayItems.enumerated() {
            let (status, networksInGroup) = item
            let row = index / gridSize
            let col = index % gridSize
            
            let x = CGFloat(col) * cellWidth
            let y = CGFloat(row) * cellHeight
            let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            
            // Draw colored rectangle for status
            let color = status.color
            bitmap.setFillColor(color.cgColor)
            bitmap.fill(rect)
            
            // Draw count or letter
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            
            let text: String
            if networksInGroup.count == 1 {
                text = String(networksInGroup[0].name.first ?? "N")
            } else {
                text = String(networksInGroup.count)
            }
            
            let textSize = text.size(withAttributes: attributes)
            let textRect = CGRect(
                x: x + (cellWidth - textSize.width) / 2,
                y: y + (cellHeight - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: textRect, withAttributes: attributes)
        }
        
        // Draw border around cells
        bitmap.setStrokeColor(NSColor.black.cgColor)
        bitmap.setLineWidth(1.0)
        
        for i in 1..<gridSize {
            // Vertical lines
            let x = CGFloat(i) * cellWidth
            bitmap.move(to: CGPoint(x: x, y: 0))
            bitmap.addLine(to: CGPoint(x: x, y: size.height))
            bitmap.strokePath()
            
            // Horizontal lines
            let y = CGFloat(i) * cellHeight
            bitmap.move(to: CGPoint(x: 0, y: y))
            bitmap.addLine(to: CGPoint(x: size.width, y: y))
            bitmap.strokePath()
        }
        
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
        case .notChecked:
            return "Not Checked"
        case .availableWithNotChecked:
            return "Available (Some checks pending)"
        case .partiallyAvailableWithNotChecked:
            return "Partially Available (Some checks pending)"
        case .unavailableWithNotChecked:
            return "Unavailable (Some checks pending)"
        }
    }
    
    func updateMenu(for networks: [Network]) {
        menuManager?.networks = networks
        if let statusItem = statusItem {
            statusItem.menu = menuManager?.createMenu()
        }
    }
    
    func refreshAllMenus(for networks: [Network]) {
        updateMenu(for: networks)
    }
}

class UnifiedMenuManager {
    var networks: [Network]
    var onConfigure: (() -> Void)?
    var onRefresh: (() -> Void)?
    
    init(networks: [Network]) {
        self.networks = networks
    }
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Title
        let titleItem = NSMenuItem(title: "NetCheck - \(networks.count) Networks", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Add each network as a submenu
        for network in networks {
            let networkMenuItem = NSMenuItem(title: network.name, action: nil, keyEquivalent: "")
            networkMenuItem.submenu = createNetworkMenu(for: network)
            menu.addItem(networkMenuItem)
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
    
    private func createNetworkMenu(for network: Network) -> NSMenu {
        let menu = NSMenu()
        
        // Status
        let statusItem = NSMenuItem(title: "Status: \(statusString(for: network.status))", action: nil, keyEquivalent: "")
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
        
        // Check results
        for check in network.checks {
            let status: String
            switch check.status {
            case .available:
                status = "✓"
            case .unavailable:
                status = "✗"
            case .notChecked:
                status = "○"
            }
            
            let checkItem = NSMenuItem(title: "\(status) \(check.description)", action: nil, keyEquivalent: "")
            checkItem.isEnabled = false
            menu.addItem(checkItem)
        }
        
        return menu
    }
    
    private func statusString(for status: NetworkStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .partiallyAvailable:
            return "Partially Available"
        case .unavailable:
            return "Unavailable"
        case .notChecked:
            return "Not Checked"
        case .availableWithNotChecked:
            return "Available (Some checks pending)"
        case .partiallyAvailableWithNotChecked:
            return "Partially Available (Some checks pending)"
        case .unavailableWithNotChecked:
            return "Unavailable (Some checks pending)"
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