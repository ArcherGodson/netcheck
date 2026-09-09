import SwiftUI
import AppKit

class ConfigWindow: NSWindow {
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NetCheck Configuration"
        let contentView = ConfigView(config: config, onSave: onSave, window: self)
        self.contentViewController = NSHostingController(rootView: contentView)
        self.center()
        self.minSize = NSSize(width: 600, height: 500)
    }
}

struct ConfigView: View {
    @State private var config: AppConfig
    private let onSave: (AppConfig) -> Void
    @State private var editingNetwork: NetworkCheck?
    let window: NSWindow
    
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void, window: NSWindow) {
        self._config = State(initialValue: config)
        self.onSave = onSave
        self.window = window
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Network Configuration")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                // Check interval settings
                HStack {
                    Text("Check Interval:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("", value: $config.checkInterval, formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                        
                        Stepper("", value: $config.checkInterval, in: 5...300, step: 5)
                            .labelsHidden()
                    }
                    .frame(width: 120)
                    
                    Text("seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
            }
            
            Divider()
            
            // Networks list
            List {
                ForEach($config.networks) { $network in
                    NetworkRow(network: $network, onEdit: {
                        editingNetwork = network
                        showNetworkEditSheet()
                    }, onDelete: {
                        if let index = config.networks.firstIndex(where: { $0.id == network.id }) {
                            config.networks.remove(at: index)
                        }
                    })
                }
                .onDelete(perform: { indexes in
                    for index in indexes {
                        if index < config.networks.count {
                            config.networks.remove(at: index)
                        }
                    }
                })
            }
            .frame(height: 350)
            .onAppear {
                // Initial setup if needed
            }
            
            // Add button
            HStack {
                Spacer()
                Button(action: {
                    editingNetwork = nil
                    showNetworkEditSheet()
                }) {
                    Label("Add Network", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            
            // Save button
            HStack {
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
        }
        .padding()
    }
    
    private func showNetworkEditSheet() {
        let editWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        editWindow.title = editingNetwork?.name.isEmpty == false ? "Edit Network" : "Add Network"
        let contentView = NetworkEditView(
            network: editingNetwork ?? NetworkCheck(name: "", host: "", protocols: []),
            onSave: { updatedNetwork in
                if let index = config.networks.firstIndex(where: { $0.id == updatedNetwork.id }) {
                    config.networks[index] = updatedNetwork
                } else {
                    config.networks.append(updatedNetwork)
                }
                editWindow.close()
            },
            window: editWindow
        )
        editWindow.contentViewController = NSHostingController(rootView: contentView)
        editWindow.center()
        editWindow.makeKeyAndOrderFront(nil)
    }
}

struct ConfigView: View {
    @State private var config: AppConfig
    private let onSave: (AppConfig) -> Void
    @State private var editingNetwork: NetworkCheck?
    let window: NSWindow
    
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void, window: NSWindow) {
        self._config = State(initialValue: config)
        self.onSave = onSave
        self.window = window
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Network Configuration")
                .font(.title)
                .fontWeight(.bold)
            
            // Check interval
            HStack {
                Text("Check Interval (seconds):")
                TextField("", value: $config.checkInterval, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Stepper("", value: $config.checkInterval, in: 5...300, step: 5)
            }
            
            Divider()
            
            // Networks list
            List {
                ForEach($config.networks) { $network in
                    NetworkRow(network: $network, onEdit: {
                        editingNetwork = network
                        showNetworkEditSheet()
                    }, onDelete: {
                        if let index = config.networks.firstIndex(where: { $0.id == network.id }) {
                            config.networks.remove(at: index)
                        }
                    })
                }
            }
            .frame(height: 250)
            .onAppear {
                // Initial setup if needed
            }
            
            // Add button
            Button(action: {
                editingNetwork = nil
                showNetworkEditSheet()
            }) {
                Label("Add Network", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            
            // Save button
            HStack {
                Spacer()
                Button("Save") {
                    onSave(config)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                Button("Cancel") {
                    window.close()
                }
            }
        }
        .padding()
    }
    
    private func showNetworkEditSheet() {
        let editWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        editWindow.title = editingNetwork?.name.isEmpty == false ? "Edit Network" : "Add Network"
        let contentView = NetworkEditView(
            network: editingNetwork ?? NetworkCheck(name: "", host: "", protocols: []),
            onSave: { network in
                if editingNetwork != nil {
                    // Update existing
                    if let index = config.networks.firstIndex(where: { $0.id == network.id }) {
                        config.networks[index] = network
                    }
                } else {
                    // Add new
                    config.networks.append(network)
                }
                editWindow.close()
                editingNetwork = nil
            },
            window: editWindow
        )
        
        editWindow.contentViewController = NSHostingController(rootView: contentView)
        editWindow.center()
        editWindow.makeKeyAndOrderFront(nil)
    }
    
}

struct NetworkRow: View {
    @Binding var network: NetworkCheck
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(network.name)
                    .font(.headline)
                Text(network.host)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(network.status.colorSwiftUI)
                .frame(width: 12, height: 12)
            
            // Protocols count
            Text("\(network.protocols.count) protocols")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }
    }
}

struct NetworkRow: View {
    @Binding var network: NetworkCheck
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(network.name.isEmpty ? "Unnamed Network" : network.name)
                    .font(.headline)
                
                Text(network.host)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(network.getProtocolDescription())
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if network.protocols.contains(.dns) {
                    Image(systemName: "network")
                        .foregroundColor(.blue)
                        .help("DNS Protocol")
                }
                
                if network.protocols.contains(.tcp) || network.protocols.contains(.customTCP) {
                    Image(systemName: "wifi")
                        .foregroundColor(.green)
                        .help("TCP Protocol")
                }
                
                if network.protocols.contains(.icmp) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .foregroundColor(.orange)
                        .help("ICMP Protocol")
                }
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ProtocolSelectionRow: View {
    let protocolType: ProtocolType
    @Binding var isSelected: Bool
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        Toggle(isOn: $isSelected) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .toggleStyle(.button)
        .buttonStyle(.borderless)
        .padding(8)
        .background(isSelected ? color.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? color : Color.clear, lineWidth: isSelected ? 2 : 0)
        )
    }
}
}

struct NetworkEditView: View {
    @State private var network: NetworkCheck
    private let onSave: (NetworkCheck) -> Void
    let window: NSWindow
    
    init(network: NetworkCheck, onSave: @escaping (NetworkCheck) -> Void, window: NSWindow) {
        self._network = State(initialValue: network)
        self.onSave = onSave
        self.window = window
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(network.name.isEmpty ? "Add Network" : "Edit Network")
                .font(.title)
                .fontWeight(.bold)
            
            // Name
            HStack {
                Text("Name:")
                    .frame(width: 100, alignment: .leading)
                TextField("Network name", text: $network.name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Host
            HStack {
                Text("Host:")
                    .frame(width: 100, alignment: .leading)
                TextField("hostname or IP", text: $network.host)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Protocols
            VStack(alignment: .leading) {
                Text("Protocols:")
                    .font(.headline)
                
                ForEach(ProtocolType.allCases, id: \.self) { protocolType in
                    Toggle(protocolType.rawValue, isOn: Binding(
                        get: { network.protocols.contains(protocolType) },
                        set: { isOn in
                            if isOn {
                                network.protocols.append(protocolType)
                            } else {
                                network.protocols.removeAll { $0 == protocolType }
                            }
                        }
                    ))
                }
            }
            
            // Custom port
            if network.protocols.contains(.tcp) || network.protocols.contains(.customTCP) {
                HStack {
                    Text("Custom Port:")
                        .frame(width: 100, alignment: .leading)
                    TextField("Port number", value: $network.customPort, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    window.close()
                }
                Spacer()
                Button("Save") {
                    onSave(network)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .disabled(network.name.isEmpty || network.host.isEmpty || network.protocols.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}