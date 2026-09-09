import Foundation
import AppKit
import SwiftUI

enum ProtocolType: String, CaseIterable, Codable {
    case icmp = "ICMP"
    case dns = "DNS"
    case tcp = "TCP"
    case ssh = "SSH"
    case http = "HTTP"
    case https = "HTTPS"
    case customTCP = "Custom TCP"
}

enum NetworkStatus: Equatable, Codable {
    case available
    case partiallyAvailable
    case unavailable
    
    var color: NSColor {
        switch self {
        case .available:
            return .systemGreen
        case .partiallyAvailable:
            return .systemYellow
        case .unavailable:
            return .systemRed
        }
    }
    
    var colorSwiftUI: Color {
        switch self {
        case .available:
            return .green
        case .partiallyAvailable:
            return .yellow
        case .unavailable:
            return .red
        }
    }
}

struct NetworkCheck: Codable, Identifiable {
    let id: UUID
    var name: String
    var host: String
    var protocols: [ProtocolType]
    var customPort: Int?
    var status: NetworkStatus
    var lastCheck: Date?
    var protocolResults: [ProtocolType: Bool]
    
    init(name: String, host: String, protocols: [ProtocolType], customPort: Int? = nil) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.protocols = protocols
        self.customPort = customPort
        self.status = .unavailable
        self.lastCheck = nil
        self.protocolResults = [:]
    }
    
    // Custom copy initializer for editing
    init(from original: NetworkCheck) {
        self.id = original.id
        self.name = original.name
        self.host = original.host
        self.protocols = original.protocols
        self.customPort = original.customPort
        self.status = original.status
        self.lastCheck = original.lastCheck
        self.protocolResults = original.protocolResults
    }
    
    // Вспомогательный метод для получения описания проверки
    func getProtocolDescription() -> String {
        let protocolDescriptions: [String] = protocols.map { protocolType in
            switch protocolType {
            case .icmp:
                return "ICMP (ping)"
            case .dns:
                return "DNS lookup"
            case .tcp:
                return "TCP port check"
            case .ssh:
                return "SSH connection"
            case .http:
                return "HTTP request"
            case .https:
                return "HTTPS request"
            case .customTCP:
                if let port = customPort {
                    return "Custom TCP port \(port)"
                } else {
                    return "Custom TCP port (no port specified)"
                }
            }
        }
        
        return protocolDescriptions.joined(separator: ", ")
    }
    
    // Вспомогательный метод для получения описания проверки с портом
    func getDetailedDescription() -> String {
        if protocols.contains(.customTCP), let port = customPort {
            return "\(name) (\(host):\(port))"
        } else {
            return "\(name) (\(host))"
        }
    }
}

struct AppConfig: Codable {
    var networks: [NetworkCheck]
    var checkInterval: TimeInterval // in seconds
    
    init() {
        self.networks = []
        self.checkInterval = 30 // default 30 seconds
    }
    
    init(networks: [NetworkCheck], checkInterval: TimeInterval) {
        self.networks = networks
        self.checkInterval = checkInterval
    }
}