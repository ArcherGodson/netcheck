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
        let startTime = Date()
        let result: Bool
        let measuredTime: TimeInterval
        
        switch check.type {
        case .icmp:
            (result, measuredTime) = await checkICMP(host: check.host)
        case .tcp:
            if let port = check.port {
                (result, measuredTime) = await checkTCP(host: check.host, port: port)
            } else {
                result = false
                measuredTime = 0
            }
        case .dns:
            if let dnsServer = check.dnsServer {
                (result, measuredTime) = await checkDNS(host: check.host, dnsServer: dnsServer)
            } else {
                (result, measuredTime) = await checkDNS(host: check.host)
            }
        case .http:
            if let port = check.port {
                (result, measuredTime) = await checkTCP(host: check.host, port: port)
            } else {
                (result, measuredTime) = await checkTCP(host: check.host, port: 80)
            }
        case .https:
            (result, measuredTime) = await checkTCP(host: check.host, port: 443)
        case .ssh:
            (result, measuredTime) = await checkTCP(host: check.host, port: 22)
        }
        
        let endTime = Date()
        let responseTime = measuredTime > 0 ? measuredTime : endTime.timeIntervalSince(startTime) * 1000 // Convert to milliseconds
        
        var updatedCheck = check
        updatedCheck.status = result ? .available : .unavailable
        updatedCheck.lastCheck = Date()
        updatedCheck.responseTime = responseTime
        
        return updatedCheck
    }
    
    private func checkICMP(host: String) async -> (Bool, TimeInterval) {
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
                
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                // Extract response time from ping output
                var responseTime: TimeInterval = 0
                if process.terminationStatus == 0 {
                    // Parse output like: "64 bytes from 8.8.8.8: icmp_seq=0 ttl=118 time=14.2 ms"
                    if let timeRange = output.range(of: "time=", options: .caseInsensitive),
                       let msRange = output[timeRange.upperBound...].range(of: "ms", options: .caseInsensitive) {
                        let timeString = String(output[timeRange.upperBound..<msRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                        responseTime = (timeString as NSString).doubleValue
                    }
                }
                
                continuation.resume(returning: (process.terminationStatus == 0, responseTime))
            } catch {
                continuation.resume(returning: (false, 0))
            }
        }
    }
    
    private func checkDNS(host: String, dnsServer: String? = nil) async -> (Bool, TimeInterval) {
        // Skip DNS check for IP addresses
        if isIPAddress(host) {
            return (true, 0)
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
                
                let success = process.terminationStatus == 0 && !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                // DNS doesn't provide accurate timing with +short, use a reasonable estimate
                let responseTime: TimeInterval = success ? 50 : 0 // Approximate 50ms for successful DNS
                
                continuation.resume(returning: (success, responseTime))
            } catch {
                continuation.resume(returning: (false, 0))
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
    
    private func checkTCP(host: String, port: Int) async -> (Bool, TimeInterval) {
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
                
                // nc doesn't provide timing, use a reasonable estimate
                let responseTime: TimeInterval = process.terminationStatus == 0 ? 50 : 0 // Approximate 50ms for successful connection
                
                continuation.resume(returning: (process.terminationStatus == 0, responseTime))
            } catch {
                continuation.resume(returning: (false, 0))
            }
        }
    }
}