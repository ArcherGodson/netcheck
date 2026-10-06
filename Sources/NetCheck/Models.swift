import Foundation
import AppKit
import SwiftUI

// Version information
struct NetCheckVersion {
    static let major = 1
    static let minor = 5
    static let patch = 1
    static let versionString = "\(major).\(minor).\(patch)"
}

enum CheckType: String, CaseIterable, Codable {
    case icmp = "ICMP"
    case tcp = "TCP"
    case dns = "DNS"
    case http = "HTTP"
    case https = "HTTPS"
    case ssh = "SSH"
}

enum CheckStatus: Equatable, Codable {
    case available
    case unavailable
    case notChecked
    
    var color: NSColor {
        switch self {
        case .available:
            return .systemGreen
        case .unavailable:
            return .systemRed
        case .notChecked:
            return .systemGray
        }
    }
    
    var colorSwiftUI: Color {
        switch self {
        case .available:
            return .green
        case .unavailable:
            return .red
        case .notChecked:
            return .gray
        }
    }
}

struct NetworkCheck: Codable, Identifiable {
    let id: UUID
    var type: CheckType
    var host: String
    var port: Int?
    var dnsServer: String?
    var status: CheckStatus
    var lastCheck: Date?
    
    init(type: CheckType, host: String, port: Int? = nil, dnsServer: String? = nil) {
        self.id = UUID()
        self.type = type
        self.host = host
        self.port = port
        self.dnsServer = dnsServer
        self.status = .notChecked
        self.lastCheck = nil
    }
    
    // For saving to config file (without dynamic status)
    struct CheckConfig: Codable {
        let id: UUID
        let type: CheckType
        let host: String
        let port: Int?
        let dnsServer: String?
        
        init(from check: NetworkCheck) {
            self.id = check.id
            self.type = check.type
            self.host = check.host
            self.port = check.port
            self.dnsServer = check.dnsServer
        }
    }
    
    var config: CheckConfig {
        return CheckConfig(from: self)
    }
    
    init(from config: CheckConfig) {
        self.id = config.id
        self.type = config.type
        self.host = config.host
        self.port = config.port
        self.dnsServer = config.dnsServer
        self.status = .notChecked
        self.lastCheck = nil
    }
    
    var description: String {
        switch type {
        case .icmp:
            return "ICMP: \(host)"
        case .tcp:
            if let port = port {
                return "TCP: \(host):\(port)"
            }
            return "TCP: \(host)"
        case .dns:
            if let dnsServer = dnsServer {
                return "DNS: \(host) via \(dnsServer)"
            }
            return "DNS: \(host)"
        case .http:
            if let port = port {
                return "HTTP: \(host):\(port)"
            }
            return "HTTP: \(host)"
        case .https:
            return "HTTPS: \(host)"
        case .ssh:
            return "SSH: \(host)"
        }
    }
}

enum NetworkStatus: Equatable, Codable {
    case available
    case partiallyAvailable
    case unavailable
    case notChecked
    case availableWithNotChecked // блёклый зелёный
    case partiallyAvailableWithNotChecked // блёклый оранжевый
    case unavailableWithNotChecked // блёклый красный
    
    var color: NSColor {
        switch self {
        case .available:
            return .systemGreen
        case .partiallyAvailable:
            return .systemYellow
        case .unavailable:
            return .systemRed
        case .notChecked:
            return .systemGray
        case .availableWithNotChecked:
            return NSColor.systemGreen.withAlphaComponent(0.5)
        case .partiallyAvailableWithNotChecked:
            return NSColor.systemYellow.withAlphaComponent(0.5)
        case .unavailableWithNotChecked:
            return NSColor.systemRed.withAlphaComponent(0.5)
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
        case .notChecked:
            return .gray
        case .availableWithNotChecked:
            return .green.opacity(0.5)
        case .partiallyAvailableWithNotChecked:
            return .yellow.opacity(0.5)
        case .unavailableWithNotChecked:
            return .red.opacity(0.5)
        }
    }
}

struct Network: Codable, Identifiable {
    let id: UUID
    var name: String
    var checks: [NetworkCheck]
    var status: NetworkStatus
    var lastCheck: Date?
    
    init(name: String, checks: [NetworkCheck] = []) {
        self.id = UUID()
        self.name = name
        self.checks = checks
        self.status = .notChecked
        self.lastCheck = nil
    }
    
    // Custom copy initializer for editing
    init(from original: Network) {
        self.id = original.id
        self.name = original.name
        self.checks = original.checks
        self.status = original.status
        self.lastCheck = original.lastCheck
    }
}

struct AppConfig: Codable {
    var networks: [Network]
    var checkInterval: TimeInterval // in seconds
    
    init() {
        self.networks = []
        self.checkInterval = 30 // default 30 seconds
    }
    
    init(networks: [Network], checkInterval: TimeInterval) {
        self.networks = networks
        self.checkInterval = checkInterval
    }
}