import XCTest
@testable import NetCheck

final class NetCheckTests: XCTestCase {
    
    func testNetworkStatusColors() throws {
        // Test that network status has correct colors
        XCTAssertEqual(NetworkStatus.available.color, .systemGreen)
        XCTAssertEqual(NetworkStatus.partiallyAvailable.color, .systemYellow)
        XCTAssertEqual(NetworkStatus.unavailable.color, .systemRed)
    }
    
    func testNetworkCheckInitialization() throws {
        // Test default network check initialization
        let network = NetworkCheck(
            name: "Test Network",
            host: "192.168.1.1",
            protocols: [.icmp]
        )
        
        XCTAssertEqual(network.name, "Test Network")
        XCTAssertEqual(network.host, "192.168.1.1")
        XCTAssertEqual(network.protocols, [.icmp])
        XCTAssertEqual(network.status, .unavailable)
        XCTAssertNil(network.lastCheck)
        XCTAssertTrue(network.protocolResults.isEmpty)
    }
    
    func testAppConfigInitialization() throws {
        // Test default app config initialization
        let config = AppConfig()
        
        XCTAssertTrue(config.networks.isEmpty)
        XCTAssertEqual(config.checkInterval, 30.0)
    }
}
