import SwiftUI
import AppKit

class ConfigWindow: NSWindow {
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NetCheck Configuration"
        let contentView = ConfigView(config: config, onSave: onSave, window: self)
        self.contentViewController = NSHostingController(rootView: contentView)
        self.center()
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