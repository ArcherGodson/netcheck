import SwiftUI
import AppKit

class ConfigWindow: NSWindow {
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 750),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NetCheck Configuration"
        let contentView = ConfigView(config: config, onSave: onSave, window: self)
        self.contentViewController = NSHostingController(rootView: contentView)
        self.center()
        self.minSize = NSSize(width: 900, height: 650)
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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Network Configuration")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Check interval
                HStack(spacing: 12) {
                    Text("Check Interval:")
                        .font(.body)
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
                        .frame(width: 70)
                        .font(.body)
                    
                    Stepper("", value: Binding(
                        get: { config.checkInterval },
                        set: { newValue in
                            var newConfig = config
                            newConfig.checkInterval = newValue
                            onSave(newConfig)
                        }
                    ), in: 5...300, step: 5)
                        .labelsHidden()
                    
                    Text("seconds")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .padding(20)
            
            Divider()
            
            // Networks list
            ScrollView {
                VStack(spacing: 12) {
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
                .padding(20)
            }
            
            Divider()
            
            // Bottom buttons
            HStack(spacing: 16) {
                Button(action: {
                    let newNetwork = Network(name: "New Network")
                    var newConfig = config
                    newConfig.networks.append(newNetwork)
                    onSave(newConfig)
                    showNetworkEditSheet(network: newNetwork)
                }) {
                    Label("Add Network", systemImage: "plus")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Spacer()
                
                Button("Cancel") {
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Save") {
                    onSave(config)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(config.networks.isEmpty)
            }
            .padding(20)
        }
    }
    
    private func showNetworkEditSheet(network: Network) {
        let editWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 800),
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
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(network.name.isEmpty ? "Unnamed Network" : network.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    Text("\(network.checks.count) checks")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(network.status.colorSwiftUI)
                        .frame(width: 10, height: 10)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button(action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .foregroundColor(.red)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
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
        VStack(spacing: 20) {
            // Network name
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Enter network name", text: Binding(
                    get: { network.name },
                    set: { newName in
                        var updatedNetwork = network
                        updatedNetwork.name = newName
                        onUpdate(updatedNetwork)
                    }
                ))
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            
            Divider()
            
            // Checks section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Network Checks")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        let newCheck = NetworkCheck(type: .icmp, host: "")
                        var updatedNetwork = network
                        updatedNetwork.checks.append(newCheck)
                        onUpdate(updatedNetwork)
                    }) {
                        Label("Add Check", systemImage: "plus")
                            .font(.body)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                
                // Checks list
                ScrollView {
                    VStack(spacing: 12) {
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
                    .padding(4)
                }
                .frame(height: 400)
            }
            
            Divider()
            
            // Buttons
            HStack {
                Button("Close") {
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
            }
        }
        .padding(24)
    }
}

struct CheckRow: View {
    let check: NetworkCheck
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(check.description)
                    .font(.body)
                    .fontWeight(.medium)
                
                HStack(spacing: 6) {
                    Text(check.type.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(check.status.colorSwiftUI)
                        .frame(width: 8, height: 8)
                }
            }
            
            Spacer()
            
            Button(action: onDelete) {
                Label("Remove", systemImage: "trash")
                    .font(.body)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .foregroundColor(.red)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}