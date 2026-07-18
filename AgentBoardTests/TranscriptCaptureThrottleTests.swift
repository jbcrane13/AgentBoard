@testable import AgentBoardCompanionKit
import Foundation
import Testing

/// Coverage for the pure throttle rule that keeps the companion's transcript
/// capture step to roughly once per `TranscriptCaptureThrottle.interval`,
/// independent of how often the probe snapshot loop itself runs.
struct TranscriptCaptureThrottleTests {
    @Test
    func shouldCaptureWhenNeverCapturedBefore() {
        #expect(TranscriptCaptureThrottle.shouldCapture(lastCaptureAt: nil, now: Date()))
    }

    @Test
    func shouldNotCaptureBeforeIntervalElapses() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let lastCaptureAt = now.addingTimeInterval(-(TranscriptCaptureThrottle.interval - 1))
        #expect(!TranscriptCaptureThrottle.shouldCapture(lastCaptureAt: lastCaptureAt, now: now))
    }

    @Test
    func shouldCaptureOnceIntervalHasElapsed() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let lastCaptureAt = now.addingTimeInterval(-TranscriptCaptureThrottle.interval)
        #expect(TranscriptCaptureThrottle.shouldCapture(lastCaptureAt: lastCaptureAt, now: now))
    }
}
