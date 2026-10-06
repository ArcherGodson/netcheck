import Foundation

@MainActor
class ConfigManager {
    static let shared = ConfigManager()
    
    private let configURL: URL
    private var verbose: Bool = false
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("NetCheck", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        configURL = appDirectory.appendingPathComponent("config.json")
    }
    
    func setVerbose(_ verbose: Bool) {
        self.verbose = verbose
    }
    
    func loadConfig() -> AppConfig {
        // Try to load config, if it fails or is incompatible, return default
        guard let data = try? Data(contentsOf: configURL) else {
            return AppConfig()
        }
        
        do {
            let config = try JSONDecoder().decode(AppConfig.self, from: data)
            // Reset all dynamic statuses to notChecked
            var cleanConfig = config
            for i in 0..<cleanConfig.networks.count {
                for j in 0..<cleanConfig.networks[i].checks.count {
                    cleanConfig.networks[i].checks[j].status = .notChecked
                    cleanConfig.networks[i].checks[j].lastCheck = nil
                    cleanConfig.networks[i].checks[j].responseTime = nil
                }
                cleanConfig.networks[i].status = .notChecked
                cleanConfig.networks[i].lastCheck = nil
            }
            return cleanConfig
        } catch {
            // If decoding fails (likely due to format change), return default config
            if verbose {
                print("Failed to decode config, using default: \(error)")
            }
            return AppConfig()
        }
    }
    
    func saveConfig(_ config: AppConfig) async {
        // Create a clean config without dynamic statuses
        var cleanConfig = config
        for i in 0..<cleanConfig.networks.count {
            for j in 0..<cleanConfig.networks[i].checks.count {
                cleanConfig.networks[i].checks[j].status = .notChecked
                cleanConfig.networks[i].checks[j].lastCheck = nil
                cleanConfig.networks[i].checks[j].responseTime = nil
            }
            cleanConfig.networks[i].status = .notChecked
            cleanConfig.networks[i].lastCheck = nil
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(cleanConfig) {
            try? data.write(to: configURL)
        }
    }
    
    func getConfigURL() -> URL {
        return configURL
    }
}