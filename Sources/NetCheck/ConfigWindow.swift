import SwiftUI
import AppKit
import os.log

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
    private var config: AppConfig
    private let onSave: (AppConfig) -> Void
    let window: NSWindow
    
    init(config: AppConfig, onSave: @escaping (AppConfig) -> Void, window: NSWindow) {
        self.config = config
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
                    
                    Text("\(Int(config.checkInterval))")
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Stepper("", value: Binding(
                        get: { config.checkInterval },
                        set: { newValue in
                            DiagnosticLogger.shared.log("Interval changed to: \(newValue)")
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
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Networks list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(config.networks) { network in
                        NetworkRow(network: network, onEdit: {
                            DiagnosticLogger.shared.log("Edit button pressed for network: \(network.name)")
                            showNetworkEditSheet(network: network)
                        }, onDelete: {
                            DiagnosticLogger.shared.log("Delete button pressed for network: \(network.name)")
                            var newConfig = config
                            if let index = newConfig.networks.firstIndex(where: { $0.id == network.id }) {
                                newConfig.networks.remove(at: index)
                                onSave(newConfig)
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
                    DiagnosticLogger.shared.log("Cancel button pressed")
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button("Save") {
                    DiagnosticLogger.shared.log("Save button pressed")
                    onSave(config)
                    window.close()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(config.networks.isEmpty)
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
        
        let editWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 900),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        editWindow.title = network.name.isEmpty ? "Add Network" : "Edit Network"
        let contentView = NetworkEditView(
            network: network,
            onUpdate: { updatedNetwork in
                DiagnosticLogger.shared.log("Network updated: \(updatedNetwork.name)")
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
        let hostingController = NSHostingController(rootView: contentView)
        editWindow.contentViewController = hostingController
        
        // Force the window to have the correct size
        editWindow.setContentSize(NSSize(width: 900, height: 900))
        editWindow.center()
        editWindow.makeKeyAndOrderFront(nil)
        
        DiagnosticLogger.shared.log("Edit window created and shown with size: \(editWindow.frame.size)")
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
    private var network: Network
    private let onUpdate: (Network) -> Void
    let window: NSWindow
    
    init(network: Network, onUpdate: @escaping (Network) -> Void, window: NSWindow) {
        self.network = network
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
                
                TextField("Enter network name", text: Binding(
                    get: { network.name },
                    set: { newName in
                        DiagnosticLogger.shared.log("Network name changed to: \(newName)")
                        var updatedNetwork = network
                        updatedNetwork.name = newName
                        onUpdate(updatedNetwork)
                    }
                ))
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
                        var updatedNetwork = network
                        let newCheck = NetworkCheck(type: .icmp, host: "")
                        updatedNetwork.checks.append(newCheck)
                        onUpdate(updatedNetwork)
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
                        ForEach(network.checks) { check in
                            CheckRow(check: check, onDelete: {
                                DiagnosticLogger.shared.log("Remove Check button pressed")
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
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Buttons
            HStack {
                Button("Close") {
                    DiagnosticLogger.shared.log("Close button pressed in edit view")
                    window.close()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            DiagnosticLogger.shared.log("NetworkEditView appeared with \(network.checks.count) checks, window size: \(window.frame.size)")
        }
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
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
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