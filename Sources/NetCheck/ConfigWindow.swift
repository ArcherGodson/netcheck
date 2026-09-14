import SwiftUI
import AppKit

class ConfigWindow: NSWindow {
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NetCheck Configuration"
        let contentView = ConfigView(config: config, onSave: onSave, window: self)
        self.contentViewController = NSHostingController(rootView: contentView)
        self.center()
        self.minSize = NSSize(width: 800, height: 600)
    }
}

struct ConfigView: View {
    private var config: AppConfig
    private let onSave: (AppConfig) -> Void
    let window: NSWindow
    
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void, window: NSWindow) {
        self.config = config
        self.onSave = onSave
        self.window = window
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Network Configuration")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Check interval
                HStack(spacing: 8) {
                    Text("Interval:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("", value: Binding(
                        get: { config.checkInterval },
                        set: { newValue in
                            var newConfig = config
                            newConfig.checkInterval = newValue
                            onSave(newConfig)
                        }
                    ), formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                        .font(.caption)
                    
                    Stepper("", value: Binding(
                        get: { config.checkInterval },
                        set: { newValue in
                            var newConfig = config
                            newConfig.checkInterval = newValue
                            onSave(newConfig)
                        }
                    ), in: 5...300, step: 5)
                        .labelsHidden()
                        .controlSize(.small)
                    
                    Text("sec")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
            }
            
            Divider()
            
            // Networks list
            List {
                ForEach(config.networks) { network in
                    NetworkRow(network: network, onEdit: {
                        showNetworkEditSheet(network: network)
                    }, onDelete: {
                        var newConfig = config
                        if let index = newConfig.networks.firstIndex(where: { $0.id == network.id }) {
                            newConfig.networks.remove(at: index)
                            onSave(newConfig)
                        }
                    })
                }
            }
            .frame(height: 400)
            
            // Add button
            HStack {
                Button(action: {
                    let newNetwork = Network(name: "New Network")
                    var newConfig = config
                    newConfig.networks.append(newNetwork)
                    onSave(newConfig)
                    showNetworkEditSheet(network: newNetwork)
                }) {
                    Label("Add Network", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Spacer()
            }
            
            // Save button
            HStack {
                Button("Cancel") {
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Spacer()
                
                Button("Save") {
                    onSave(config)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(config.networks.isEmpty)
            }
        }
        .padding(20)
    }
    
    private func showNetworkEditSheet(network: Network) {
        let editWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        editWindow.title = network.name.isEmpty ? "Add Network" : "Edit Network"
        let contentView = NetworkEditView(
            network: network,
            onUpdate: { updatedNetwork in
                var newConfig = config
                if let index = newConfig.networks.firstIndex(where: { $0.id == updatedNetwork.id }) {
                    newConfig.networks[index] = updatedNetwork
                } else {
                    newConfig.networks.append(updatedNetwork)
                }
                onSave(newConfig)
                editWindow.close()
            },
            window: editWindow
        )
        editWindow.contentViewController = NSHostingController(rootView: contentView)
        editWindow.center()
        editWindow.makeKeyAndOrderFront(nil)
    }
}

struct NetworkRow: View {
    let network: Network
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(network.name.isEmpty ? "Unnamed Network" : network.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Text("\(network.checks.count) checks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(network.status.colorSwiftUI)
                        .frame(width: 6, height: 6)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct NetworkEditView: View {
    private var network: Network
    private let onUpdate: (Network) -> Void
    let window: NSWindow
    
    init(network: Network, onUpdate: @escaping (Network) -> Void, window: NSWindow) {
        self.network = network
        self.onUpdate = onUpdate
        self.window = window
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Network name
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Name")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Network name", text: Binding(
                    get: { network.name },
                    set: { newName in
                        var updatedNetwork = network
                        updatedNetwork.name = newName
                        onUpdate(updatedNetwork)
                    }
                ))
                    .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            // Checks section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Checks")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        let newCheck = NetworkCheck(type: .icmp, host: "")
                        var updatedNetwork = network
                        updatedNetwork.checks.append(newCheck)
                        onUpdate(updatedNetwork)
                    }) {
                        Label("Add Check", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                // Checks list
                List {
                    ForEach(network.checks) { check in
                        CheckRow(check: check, onDelete: {
                            var updatedNetwork = network
                            if let index = updatedNetwork.checks.firstIndex(where: { $0.id == check.id }) {
                                updatedNetwork.checks.remove(at: index)
                                onUpdate(updatedNetwork)
                            }
                        })
                    }
                }
                .frame(height: 300)
            }
            
            // Buttons
            HStack {
                Button("Close") {
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Spacer()
            }
        }
        .padding(20)
    }
}

struct CheckRow: View {
    let check: NetworkCheck
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(check.description)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Circle()
                    .fill(check.status.colorSwiftUI)
                    .frame(width: 6, height: 6)
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}