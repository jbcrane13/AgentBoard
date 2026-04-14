import Foundation
import os

// Stub ObservabilityService - Sentry not available
@MainActor
final class ObservabilityService: ObservableObject {
    static let shared = ObservabilityService()
    
    private init() {}
    
    func capture(error: Error) {
        Logger.observability.error("Error: \(error.localizedDescription)")
    }
    
    func addBreadcrumb(message: String, category: String, level: String = "info") {
        Logger.observability.info("Breadcrumb: \(message)")
    }
    
    func setUser(id: String, email: String?) {
        Logger.observability.info("User set: \(id)")
    }
}

private extension Logger {
    static let observability = Logger(subsystem: "com.agentboard", category: "observability")
}
