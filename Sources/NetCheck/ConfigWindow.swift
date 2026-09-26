import SwiftUI
import AppKit

class ConfigWindow: NSWindow {
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NetCheck Configuration"
        let contentView = ConfigView(config: config, onSave: onSave, window: self)
        let hostingController = NSHostingController(rootView: contentView)
        self.contentViewController = hostingController
        
        // Force the window to have the correct size
        self.setContentSize(NSSize(width: 1200, height: 900))
        self.center()
        self.minSize = NSSize(width: 1000, height: 800)
        
        DiagnosticLogger.shared.log("ConfigWindow initialized with size: \(self.frame.size)")
    }
}

struct ConfigView: View {
    @ObservedObject private var viewModel: ConfigViewModel
    private let onSave: (AppConfig) -> Void
    let window: NSWindow
    
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void, window: NSWindow) {
        self.viewModel = ConfigViewModel(config: config)
        self.onSave = onSave
        self.window = window
        DiagnosticLogger.shared.log("ConfigView initialized with \(config.networks.count) networks")
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
                    
                    Text("\(Int(viewModel.config.checkInterval))")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Stepper("", value: $viewModel.config.checkInterval, in: 5...300, step: 5)
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
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Networks list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(viewModel.config.networks) { network in
                        NetworkRow(network: network, onEdit: {
                            DiagnosticLogger.shared.log("Edit button pressed for network: \(network.name)")
                            showNetworkEditSheet(network: network)
                        }, onDelete: {
                            DiagnosticLogger.shared.log("Delete button pressed for network: \(network.name)")
                            if let index = viewModel.config.networks.firstIndex(where: { $0.id == network.id }) {
                                viewModel.config.networks.remove(at: index)
                                onSave(viewModel.config)
                            }
                        })
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Bottom buttons
            HStack(spacing: 16) {
                Button(action: {
                    DiagnosticLogger.shared.log("Add Network button pressed")
                    let newNetwork = Network(name: "New Network")
                    viewModel.config.networks.append(newNetwork)
                    onSave(viewModel.config)
                    showNetworkEditSheet(network: newNetwork)
                }) {
                    Label("Add Network", systemImage: "plus")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Spacer()
                
                Button("Cancel") {
                    DiagnosticLogger.shared.log("Cancel button pressed")
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    DiagnosticLogger.shared.log("Save button pressed")
                    onSave(viewModel.config)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(viewModel.config.networks.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DiagnosticLogger.shared.log("ConfigView appeared with window size: \(window.frame.size)")
        }
    }
    
    private func showNetworkEditSheet(network: Network) {
        DiagnosticLogger.shared.log("Opening edit sheet for network: \(network.name)")
        
        let editWindow = EditWindow(
            network: network,
            onUpdate: { updatedNetwork in
                DiagnosticLogger.shared.log("Network updated: \(updatedNetwork.name)")
                if let index = viewModel.config.networks.firstIndex(where: { $0.id == updatedNetwork.id }) {
                    viewModel.config.networks[index] = updatedNetwork
                } else {
                    viewModel.config.networks.append(updatedNetwork)
                }
                onSave(viewModel.config)
            }
        )
        
        editWindow.makeKeyAndOrderFront(nil)
        
        DiagnosticLogger.shared.log("Edit window created and shown with size: \(editWindow.frame.size)")
    }
}

class EditWindow: NSWindow {
    init(network: Network, onUpdate: @escaping (Network) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 900),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = network.name.isEmpty ? "Add Network" : "Edit Network"
        self.level = .normal
        self.hidesOnDeactivate = false
        self.minSize = NSSize(width: 700, height: 700)
        
        let contentView = NetworkEditView(
            network: network,
            onUpdate: onUpdate,
            window: self
        )
        let hostingController = NSHostingController(rootView: contentView)
        self.contentViewController = hostingController
        
        self.setContentSize(NSSize(width: 900, height: 900))
        self.center()
        
        DiagnosticLogger.shared.log("EditWindow initialized with size: \(self.frame.size)")
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
                Button(action: {
                    DiagnosticLogger.shared.log("NetworkRow Edit button pressed for: \(network.name)")
                    onEdit()
                }) {
                    Label("Edit", systemImage: "pencil")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button(action: {
                    DiagnosticLogger.shared.log("NetworkRow Delete button pressed for: \(network.name)")
                    onDelete()
                }) {
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
    @ObservedObject private var viewModel: NetworkEditViewModel
    private let onUpdate: (Network) -> Void
    let window: NSWindow
    
    init(network: Network, onUpdate: @escaping (Network) -> Void, window: NSWindow) {
        self.viewModel = NetworkEditViewModel(network: network)
        self.onUpdate = onUpdate
        self.window = window
        DiagnosticLogger.shared.log("NetworkEditView initialized for: \(network.name)")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Network name
            VStack(alignment: .leading, spacing: 8) {
                Text("Network Name")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                TextField("Enter network name", text: $viewModel.network.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Checks section
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Network Checks")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        DiagnosticLogger.shared.log("Add Check button pressed")
                        let newCheck = NetworkCheck(type: .tcp, host: "", port: 80)
                        viewModel.network.checks.append(newCheck)
                    }) {
                        Label("Add Check", systemImage: "plus")
                            .font(.body)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .frame(maxWidth: .infinity)
                
                // Checks list
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach($viewModel.network.checks) { $check in
                            CheckRow(check: $check, onDelete: {
                                DiagnosticLogger.shared.log("Remove Check button pressed")
                                if let index = viewModel.network.checks.firstIndex(where: { $0.id == check.id }) {
                                    viewModel.network.checks.remove(at: index)
                                }
                            })
                        }
                    }
                    .padding(4)
                }
                .frame(height: 400)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    DiagnosticLogger.shared.log("Cancel button pressed in edit view")
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Save") {
                    DiagnosticLogger.shared.log("Save button pressed in edit view")
                    onUpdate(viewModel.network)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DiagnosticLogger.shared.log("NetworkEditView appeared with \(viewModel.network.checks.count) checks, window size: \(window.frame.size)")
        }
    }
}

class NetworkEditViewModel: ObservableObject {
    @Published var network: Network
    
    init(network: Network) {
        self.network = network
    }
}

struct CheckRow: View {
    @Binding var check: NetworkCheck
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Protocol type and status
            HStack(spacing: 12) {
                Picker("Protocol", selection: $check.type) {
                    Text("ICMP").tag(CheckType.icmp)
                    Text("TCP").tag(CheckType.tcp)
                    Text("DNS").tag(CheckType.dns)
                    Text("HTTP").tag(CheckType.http)
                    Text("HTTPS").tag(CheckType.https)
                    Text("SSH").tag(CheckType.ssh)
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                Spacer()
                
                Circle()
                    .fill(check.status.colorSwiftUI)
                    .frame(width: 10, height: 10)
                
                Button(action: {
                    DiagnosticLogger.shared.log("CheckRow Remove button pressed")
                    onDelete()
                }) {
                    Label("Remove", systemImage: "trash")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .foregroundColor(.red)
            }
            
            // Parameters based on check type
            VStack(alignment: .leading, spacing: 8) {
                // Host field (common for all types)
                HStack {
                    Text("Host:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 60, alignment: .leading)
                    
                    TextField("Enter host", text: $check.host)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
                
                // Port field (for TCP, HTTP, HTTPS, SSH)
                if check.type == .tcp || check.type == .http || check.type == .https || check.type == .ssh {
                    HStack {
                        Text("Port:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Port", value: Binding(
                            get: { check.port ?? defaultPort(for: check.type) },
                            set: { check.port = $0 }
                        ), formatter: NumberFormatter())
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .frame(width: 100)
                    }
                }
                
                // DNS server field (for DNS)
                if check.type == .dns {
                    HStack {
                        Text("DNS Server:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        TextField("Enter DNS server (optional)", text: Binding(
                            get: { check.dnsServer ?? "" },
                            set: { check.dnsServer = $0.isEmpty ? nil : $0 }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func defaultPort(for type: CheckType) -> Int {
        switch type {
        case .http: return 80
        case .https: return 443
        case .ssh: return 22
        case .tcp: return 80
        default: return 0
        }
    }
}

// Diagnostic logger for debugging UI issues
@MainActor
class DiagnosticLogger {
    static let shared = DiagnosticLogger()
    private let fileURL: URL
    
    private init() {
        let paths = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        let desktopURL = paths[0]
        fileURL = desktopURL.appendingPathComponent("netcheck_ui_debug.log")
        
        // Clear previous log
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        log("DiagnosticLogger initialized")
    }
    
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Also print to console for immediate feedback
        print("NetCheck UI: \(message)")
        
        // Log to file
        if let data = logMessage.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? logMessage.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        }
    }
}

// View model for configuration
class ConfigViewModel: ObservableObject {
    @Published var config: AppConfig
    
    init(config: AppConfig) {
        self.config = config
    }
}