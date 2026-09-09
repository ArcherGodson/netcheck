import Foundation
import Network

actor NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private init() {}
    
    func checkNetwork(_ network: NetworkCheck) async -> NetworkCheck {
        print("Checking network: \(network.name) (\(network.host))")
        print("Protocols to check: \(network.protocols.map { $0.rawValue })")
        
        var results: [ProtocolType: Bool] = [:]
        var availableCount = 0
        
        for protocolType in network.protocols {
            let result = await checkProtocol(protocolType, for: network)
            results[protocolType] = result
            print("  \(protocolType.rawValue): \(result ? "SUCCESS" : "FAILED")")
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
        
        print("Network status: \(updatedNetwork.status) (available: \(availableCount)/\(totalProtocols))")
        
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
                
                let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                
                print("Ping check for \(host): exit code \(process.terminationStatus), output: \(output)")
                
                continuation.resume(returning: process.terminationStatus == 0)
            } catch {
                print("Ping check for \(host) failed with error: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    private func checkDNS(host: String) async -> Bool {
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
                
                print("DNS check for \(host): exit code \(process.terminationStatus), output: \(output)")
                
                continuation.resume(returning: process.terminationStatus == 0 && !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } catch {
                print("DNS check for \(host) failed with error: \(error)")
                continuation.resume(returning: false)
            }
        }
    }
    
    private func checkTCP(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            
            let actor = TCPCheckActor()
            
            connection.stateUpdateHandler = { state in
                Task {
                    let shouldContinue = await actor.tryResume()
                    if shouldContinue {
                        print("TCP check for \(host):\(port) - state: \(state)")
                        switch state {
                        case .ready:
                            connection.cancel()
                            continuation.resume(returning: true)
                        case .failed, .waiting:
                            connection.cancel()
                            continuation.resume(returning: false)
                        default:
                            break
                        }
                    }
                }
            }
            
            connection.start(queue: .global())
            
            // Timeout after 3 seconds (reduced from 5 for faster response)
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let shouldContinue = await actor.tryResume()
                if shouldContinue {
                    print("TCP check for \(host):\(port) - timeout")
                    connection.cancel()
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

actor TCPCheckActor {
    private var hasResumed = false
    
    func tryResume() -> Bool {
        if !hasResumed {
            hasResumed = true
            return true
        }
        return false
    }
}