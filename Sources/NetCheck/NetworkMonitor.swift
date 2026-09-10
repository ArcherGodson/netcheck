import Foundation

actor NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private init() {}
    
    func checkNetwork(_ network: NetworkCheck) async -> NetworkCheck {
        var results: [ProtocolType: Bool] = [:]
        var availableCount = 0
        
        for protocolType in network.protocols {
            let result = await checkProtocol(protocolType, for: network)
            results[protocolType] = result
            if result {
                availableCount += 1
            }
        }
        
        var updatedNetwork = network
        updatedNetwork.protocolResults = results
        updatedNetwork.lastCheck = Date()
        
        let totalProtocols = network.protocols.count
        if totalProtocols == 0 {
            updatedNetwork.status = .unavailable
        } else if availableCount == totalProtocols {
            updatedNetwork.status = .available
        } else if availableCount > 0 {
            updatedNetwork.status = .partiallyAvailable
        } else {
            updatedNetwork.status = .unavailable
        }
        
        return updatedNetwork
    }
    
    private func checkProtocol(_ protocolType: ProtocolType, for network: NetworkCheck) async -> Bool {
        switch protocolType {
        case .icmp:
            return await checkICMP(host: network.host)
        case .dns:
            return await checkDNS(host: network.host)
        case .tcp:
            return await checkTCP(host: network.host, port: network.customPort ?? 80)
        case .ssh:
            return await checkTCP(host: network.host, port: 22)
        case .http:
            return await checkTCP(host: network.host, port: 80)
        case .https:
            return await checkTCP(host: network.host, port: 443)
        case .customTCP:
            guard let port = network.customPort else { return false }
            return await checkTCP(host: network.host, port: port)
        }
    }
    
    private func checkICMP(host: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
            // Use -c for count and -W for timeout (macOS version)
            process.arguments = ["-c", "1", "-W", "2000", host]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func checkDNS(host: String) async -> Bool {
        // Skip DNS check for IP addresses
        if isIPAddress(host) {
            return true // Consider IP addresses as "DNS available"
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
            process.arguments = ["+short", "+timeout=2", host]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                continuation.resume(returning: process.terminationStatus == 0 && !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
    
    private func isIPAddress(_ host: String) -> Bool {
        // Simple IPv4 address validation
        let ipv4Pattern = "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$"
        if let regex = try? NSRegularExpression(pattern: ipv4Pattern) {
            let range = NSRange(location: 0, length: host.utf16.count)
            return regex.firstMatch(in: host, options: [], range: range) != nil
        }
        return false
    }
    
    private func checkTCP(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nc")
            process.arguments = ["-z", "-w", "2", host, String(port)]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            do {
                try process.run()
                process.waitUntilExit()
                
                // nc returns 0 if connection successful, 1 if failed
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}