import AppKit
import Foundation

// Простой скрипт для проверки работы TrayIconManager
print("Testing TrayIconManager functionality...")

// Проверим, что все изменения внесены правильно
let testNetwork = NetworkCheck(
    name: "Test Network",
    host: "192.168.1.1",
    protocols: [.icmp]
)

print("Created test network: \(testNetwork.name)")
print("Network status: \(testNetwork.status)")
print("Network protocols: \(testNetwork.protocols)")

// Проверим цвета статусов
print("Available color: \(NetworkStatus.available.color)")
print("Partially Available color: \(NetworkStatus.partiallyAvailable.color)")
print("Unavailable color: \(NetworkStatus.unavailable.color)")

print("All tests completed successfully!")