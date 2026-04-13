import Foundation
import os
import Sentry

// MARK: - ObservabilityService

/// Wraps Sentry for crash reporting and error tracking.
///
/// Privacy: No PII sent to Sentry. Anonymous breadcrumbs only.
@MainActor
@Observable
final class ObservabilityService {
    static let shared = ObservabilityService()

    private let logger = Logger(subsystem: "com.agentboard", category: "Observability")
    private(set) var isInitialized = false

    private init() {}

    func configure(dsn: String? = nil, environment: String = "production") {
        guard !isInitialized else { return }

        let resolvedDSN = dsn ?? ProcessInfo.processInfo.environment["SENTRY_DSN"] ?? ""
        guard !resolvedDSN.isEmpty else {
            logger.warning("Sentry DSN not configured — error tracking disabled")
            return
        }

        SentrySDK.start { options in
            options.dsn = resolvedDSN
            options.environment = environment
            options.debug = false
            options.tracesSampleRate = NSNumber(value: environment == "production" ? 0.2 : 1.0)
            options.sendDefaultPii = false
            options.enableAutoSessionTracking = true
            options.swiftAsyncStacktraces = true
        }

        isInitialized = true
        logger.info("Sentry initialized (environment: \(environment, privacy: .public))")
    }

    func capture(error: Error, context: [String: String] = [:]) {
        SentrySDK.capture(error: error) { scope in
            for (key, value) in context {
                scope.setExtra(value: value, key: key)
            }
        }
    }

    func capture(message: String, level: SentryLevel = .info) {
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
        }
    }

    func addBreadcrumb(category: String, message: String, level: SentryLevel = .info) {
        let crumb = Breadcrumb(level: level, category: category)
        crumb.message = message
        SentrySDK.addBreadcrumb(crumb)
    }
}
