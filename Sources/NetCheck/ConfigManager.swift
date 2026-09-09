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
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
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