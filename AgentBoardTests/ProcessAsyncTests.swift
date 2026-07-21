import Foundation
import Testing

#if os(macOS)
    @Suite("Async process execution")
    struct ProcessAsyncTests {
        @Test
        func capturesOutputLargerThanPipeCapacity() async throws {
            let outputSize = 1_000_000
            let script = """
            import sys
            sys.stdout.write("x" * \(outputSize))
            sys.stderr.write("y" * \(outputSize))
            """

            let result = try await Process.runAsync(
                executablePath: "/usr/bin/python3",
                arguments: ["-c", script],
                timeout: 5
            )

            #expect(result.succeeded)
            #expect(result.stdout.count == outputSize)
            #expect(result.stderr.count == outputSize)
        }
    }
#endif
