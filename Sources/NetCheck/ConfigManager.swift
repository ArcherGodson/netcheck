import Foundation

@MainActor
class ConfigManager {
    static let shared = ConfigManager()
    
    private let configURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupport.appendingPathComponent("NetCheck", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        
        configURL = appDirectory.appendingPathComponent("config.json")
    }
    
    func loadConfig() -> AppConfig {
        // Try to load config, if it fails or is incompatible, return default
        guard let data = try? Data(contentsOf: configURL) else {
            return AppConfig()
        }
        
        do {
            return try JSONDecoder().decode(AppConfig.self, from: data)
        } catch {
            // If decoding fails (likely due to format change), return default config
            print("Failed to decode config, using default: \(error)")
            return AppConfig()
        }
    }
    
    func saveConfig(_ config: AppConfig) async {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(config) {
            try? data.write(to: configURL)
        }
    }
    
    func getConfigURL() -> URL {
        return configURL
    }
}