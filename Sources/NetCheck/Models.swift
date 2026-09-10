import Foundation
import AppKit
import SwiftUI

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
    
    var color: NSColor {
        switch self {
        case .available:
            return .systemGreen
        case .unavailable:
            return .systemRed
        }
    }
    
    var colorSwiftUI: Color {
        switch self {
        case .available:
            return .green
        case .unavailable:
            return .red
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
        self.status = .unavailable
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
        self.status = .unavailable
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