import Foundation

actor NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private init() {}
    
    func checkNetwork(_ network: Network) async -> Network {
        var updatedChecks: [NetworkCheck] = []
        var availableCount = 0
        var unavailableCount = 0
        var notCheckedCount = 0
        
        for check in network.checks {
            let result = await performCheck(check)
            updatedChecks.append(result)
            if result.status == .available {
                availableCount += 1
            } else if result.status == .unavailable {
                unavailableCount += 1
            } else {
                notCheckedCount += 1
            }
        }
        
        var updatedNetwork = network
        updatedNetwork.checks = updatedChecks
        updatedNetwork.lastCheck = Date()
        
        let totalChecks = network.checks.count
        if totalChecks == 0 {
            updatedNetwork.status = .notChecked
        } else if notCheckedCount == totalChecks {
            // Все проверки еще не выполнены
            updatedNetwork.status = .notChecked
        } else if notCheckedCount > 0 {
            // Есть хотя бы одна непроверенная проверка
            if unavailableCount == 0 {
                // Нет недоступных, значит все остальные доступны
                updatedNetwork.status = .availableWithNotChecked
            } else if availableCount == 0 {
                // Нет доступных, значит все остальные недоступны
                updatedNetwork.status = .unavailableWithNotChecked
            } else {
                // Есть и доступные, и недоступные
                updatedNetwork.status = .partiallyAvailableWithNotChecked
            }
        } else {
            // Все проверки выполнены
            if availableCount == totalChecks {
                updatedNetwork.status = .available
            } else if unavailableCount == totalChecks {
                updatedNetwork.status = .unavailable
            } else {
                updatedNetwork.status = .partiallyAvailable
            }
        }
        
        return updatedNetwork
    }
    
    private func performCheck(_ check: NetworkCheck) async -> NetworkCheck {
        let result: Bool
        
        switch check.type {
        case .icmp:
            result = await checkICMP(host: check.host)
        case .tcp:
            if let port = check.port {
                result = await checkTCP(host: check.host, port: port)
            } else {
                result = false
            }
        case .dns:
            if let dnsServer = check.dnsServer {
                result = await checkDNS(host: check.host, dnsServer: dnsServer)
            } else {
                result = await checkDNS(host: check.host)
            }
        case .http:
            if let port = check.port {
                result = await checkTCP(host: check.host, port: port)
            } else {
                result = await checkTCP(host: check.host, port: 80)
            }
        case .https:
            result = await checkTCP(host: check.host, port: 443)
        case .ssh:
            result = await checkTCP(host: check.host, port: 22)
        }
        
        var updatedCheck = check
        updatedCheck.status = result ? .available : .unavailable
        updatedCheck.lastCheck = Date()
        
        return updatedCheck
    }
    
    private func checkICMP(host: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/sbin/ping")
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
    
    private func checkDNS(host: String, dnsServer: String? = nil) async -> Bool {
        // Skip DNS check for IP addresses
        if isIPAddress(host) {
            return true
        }
        
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/dig")
            
            var arguments = ["+short", "+timeout=2"]
            if let dnsServer = dnsServer {
                arguments.append("@\(dnsServer)")
            }
            arguments.append(host)
            
            process.arguments = arguments
            
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
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}