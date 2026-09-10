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
    }
}

struct ConfigView: View {
    @State private var config: AppConfig
    private let onSave: (AppConfig) -> Void
    @State private var editingNetwork: Network?
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        editWindow.title = editingNetwork?.name.isEmpty == false ? "Edit Network" : "Add Network"
        let contentView = NetworkEditView(
            network: editingNetwork ?? Network(name: ""),
            onSave: { updatedNetwork in
                if let index = config.networks.firstIndex(where: { $0.id == updatedNetwork.id }) {
                    config.networks[index] = updatedNetwork
                } else {
                    config.networks.append(updatedNetwork)
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
    @Binding var network: Network
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(network.name)
                    .font(.headline)
                Text("\(network.checks.count) checks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(network.status.colorSwiftUI)
                .frame(width: 12, height: 12)
            
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
    @State private var network: Network
    private let onSave: (Network) -> Void
    let window: NSWindow
    @State private var editingCheck: NetworkCheck?
    
    init(network: Network, onSave: @escaping (Network) -> Void, window: NSWindow) {
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
            
            Divider()
            
            // Checks list
            VStack(alignment: .leading) {
                Text("Checks:")
                    .font(.headline)
                
                List {
                    ForEach($network.checks) { $check in
                        CheckRow(check: $check, onEdit: {
                            editingCheck = check
                            showCheckEditSheet()
                        }, onDelete: {
                            if let index = network.checks.firstIndex(where: { $0.id == check.id }) {
                                network.checks.remove(at: index)
                            }
                        })
                    }
                }
                .frame(height: 200)
            }
            
            // Add check button
            Button(action: {
                editingCheck = nil
                showCheckEditSheet()
            }) {
                Label("Add Check", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            
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
                .disabled(network.name.isEmpty || network.checks.isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 600)
    }
    
    private func showCheckEditSheet() {
        let editWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        editWindow.title = editingCheck != nil ? "Edit Check" : "Add Check"
        let contentView = CheckEditView(
            check: editingCheck ?? NetworkCheck(type: .icmp, host: ""),
            onSave: { updatedCheck in
                if let index = network.checks.firstIndex(where: { $0.id == updatedCheck.id }) {
                    network.checks[index] = updatedCheck
                } else {
                    network.checks.append(updatedCheck)
                }
                editWindow.close()
                editingCheck = nil
            },
            window: editWindow
        )
        editWindow.contentViewController = NSHostingController(rootView: contentView)
        editWindow.center()
        editWindow.makeKeyAndOrderFront(nil)
    }
}

struct CheckRow: View {
    @Binding var check: NetworkCheck
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(check.description)
                    .font(.caption)
                Circle()
                    .fill(check.status.colorSwiftUI)
                    .frame(width: 8, height: 8)
            }
            
            Spacer()
            
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
        .padding(.vertical, 2)
    }
}

struct CheckEditView: View {
    @State private var check: NetworkCheck
    private let onSave: (NetworkCheck) -> Void
    let window: NSWindow
    
    init(check: NetworkCheck, onSave: @escaping (NetworkCheck) -> Void, window: NSWindow) {
        self._check = State(initialValue: check)
        self.onSave = onSave
        self.window = window
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Edit Check")
                .font(.title)
                .fontWeight(.bold)
            
            // Type
            VStack(alignment: .leading) {
                Text("Type:")
                    .font(.headline)
                Picker("Type", selection: $check.type) {
                    ForEach(CheckType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Host
            HStack {
                Text("Host:")
                    .frame(width: 100, alignment: .leading)
                TextField("hostname or IP", text: $check.host)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Port (for TCP, HTTP)
            if check.type == .tcp || check.type == .http {
                HStack {
                    Text("Port:")
                        .frame(width: 100, alignment: .leading)
                    TextField("Port number", value: $check.port, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
            }
            
            // DNS Server (for DNS)
            if check.type == .dns {
                HStack {
                    Text("DNS Server:")
                        .frame(width: 100, alignment: .leading)
                    TextField("DNS server (optional)", text: Binding(
                        get: { check.dnsServer ?? "" },
                        set: { check.dnsServer = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }
            }
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    window.close()
                }
                Spacer()
                Button("Save") {
                    onSave(check)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .disabled(check.host.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}