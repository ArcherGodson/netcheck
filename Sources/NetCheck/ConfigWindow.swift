import SwiftUI
import AppKit

class ConfigWindow: NSWindow {
    init(config: AppConfig, verbose: Bool = false, onSave: @escaping (AppConfig) -> Void) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NetCheck Configuration"
        let contentView = ConfigView(config: config, verbose: verbose, onSave: onSave, window: self)
        let hostingController = NSHostingController(rootView: contentView)
        self.contentViewController = hostingController
        
        // Force the window to have the correct size
        self.setContentSize(NSSize(width: 1200, height: 900))
        self.center()
        self.minSize = NSSize(width: 1000, height: 800)
        
        // Enable text field editing and clipboard support
        self.makeKey()
        
        if verbose {
            DiagnosticLogger.shared.log("ConfigWindow initialized with size: \(self.frame.size)")
        }
    }
}

struct ConfigView: View {
    @ObservedObject private var viewModel: ConfigViewModel
    private let verbose: Bool
    private let onSave: (AppConfig) -> Void
    let window: NSWindow
    
    init(config: AppConfig, verbose: Bool = false, onSave: @escaping (AppConfig) -> Void, window: NSWindow) {
        self.verbose = verbose
        DiagnosticLogger.shared.setVerbose(verbose)
        self.viewModel = ConfigViewModel(config: config)
        self.onSave = { updatedConfig in
            // Save immediately to ConfigManager
            Task {
                await ConfigManager.shared.saveConfig(updatedConfig)
            }
            // Then call the original callback for tray icon updates
            onSave(updatedConfig)
        }
        self.window = window
        if verbose {
            DiagnosticLogger.shared.log("ConfigView initialized with \(config.networks.count) networks")
        }
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
                    
                    TextField("Interval", value: Binding(
                        get: { viewModel.config.checkInterval },
                        set: { newValue in
                            if verbose {
                                DiagnosticLogger.shared.log("Interval changed to: \(newValue)")
                            }
                            viewModel.config.checkInterval = max(1, min(300, newValue))
                            onSave(viewModel.config)
                        }
                    ), formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .frame(width: 60)
                    
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
            
            // Networks list with inline editing
            ScrollView {
                VStack(spacing: 16) {
                    ForEach($viewModel.config.networks) { $network in
                        NetworkEditorView(network: $network, verbose: verbose, onDelete: {
                            if verbose {
                                DiagnosticLogger.shared.log("Delete button pressed for network: \(network.name)")
                            }
                            if let index = viewModel.config.networks.firstIndex(where: { $0.id == network.id }) {
                                viewModel.config.networks.remove(at: index)
                                onSave(viewModel.config)
                            }
                        }, onSave: {
                            onSave(viewModel.config)
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
                    if verbose {
                        DiagnosticLogger.shared.log("Add Network button pressed")
                    }
                    let newNetwork = Network(name: "New Network")
                    viewModel.config.networks.append(newNetwork)
                    onSave(viewModel.config)
                }) {
                    Label("Add Network", systemImage: "plus")
                        .font(.body)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Spacer()
                
                Button("Save") {
                    if verbose {
                        DiagnosticLogger.shared.log("Save button pressed")
                    }
                    onSave(viewModel.config)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                
                Button("Cancel") {
                    if verbose {
                        DiagnosticLogger.shared.log("Cancel button pressed")
                    }
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DiagnosticLogger.shared.log("ConfigView appeared with window size: \(window.frame.size)")
        }
    }
}

struct NetworkEditorView: View {
    @Binding var network: Network
    let verbose: Bool
    let onDelete: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Network header with delete button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Network Name", text: Binding(
                        get: { network.name },
                        set: { newValue in
                            network.name = newValue
                            onSave()
                        }
                    ))
                        .textFieldStyle(.roundedBorder)
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
                
                Button(action: {
                    if verbose {
                        DiagnosticLogger.shared.log("Delete button pressed for network: \(network.name)")
                    }
                    onDelete()
                }) {
                    Label("Delete", systemImage: "trash")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .foregroundColor(.red)
            }
            
            Divider()
            
            // Checks section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Network Checks")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: {
                        if verbose {
                            DiagnosticLogger.shared.log("Add Check button pressed")
                        }
                        let newCheck = NetworkCheck(type: .tcp, host: "", port: 80)
                        network.checks.append(newCheck)
                        onSave()
                    }) {
                        Label("Add Check", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                
                // Checks list
                VStack(spacing: 8) {
                    ForEach($network.checks) { $check in
                        CheckRow(check: $check, verbose: verbose, onDelete: {
                            if verbose {
                                DiagnosticLogger.shared.log("Remove Check button pressed")
                            }
                            if let index = network.checks.firstIndex(where: { $0.id == check.id }) {
                                network.checks.remove(at: index)
                                onSave()
                            }
                        }, onSave: {
                            onSave()
                        })
                    }
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
struct CheckRow: View {
    @Binding var check: NetworkCheck
    let verbose: Bool
    let onDelete: () -> Void
    let onSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Protocol type and status
            HStack(spacing: 12) {
                Picker("Protocol", selection: Binding(
                    get: { check.type },
                    set: { newValue in
                        check.type = newValue
                        onSave()
                    }
                )) {
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
                
                Text(check.responseTimeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, alignment: .trailing)
                
                Button(action: {
                    if verbose {
                        DiagnosticLogger.shared.log("CheckRow Remove button pressed")
                    }
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
                    
                    TextField("Enter host", text: Binding(
                        get: { check.host },
                        set: { newValue in
                            check.host = newValue
                            onSave()
                        }
                    ))
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
                            set: { newValue in
                                check.port = newValue
                                onSave()
                            }
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
                            set: { newValue in
                                check.dnsServer = newValue.isEmpty ? nil : newValue
                                onSave()
                            }
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
    private var verbose: Bool = false
    
    private init() {
        let paths = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        let desktopURL = paths[0]
        fileURL = desktopURL.appendingPathComponent("netcheck_ui_debug.log")
        
        // Clear previous log
        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
        log("DiagnosticLogger initialized")
    }
    
    func setVerbose(_ verbose: Bool) {
        self.verbose = verbose
    }
    
    func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Only print to console if verbose
        if verbose {
            print("NetCheck UI: \(message)")
        }
        
        // Always log to file
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