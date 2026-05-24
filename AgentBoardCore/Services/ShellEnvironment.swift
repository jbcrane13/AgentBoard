import Foundation
import os

#if os(macOS)

    /// Harvests PATH and allowlisted credential env vars from the user's login
    /// shell so that subprocesses (tmux sessions, ralphy, etc.) can find
    /// Homebrew-managed tools like `node`, `nvm`, `ralphy`, `claude`, `codex`.
    ///
    /// Async + cache-coalesced: the first call kicks off a single probe; concurrent
    /// callers wait on the same in-flight `Task`. App bootstrap can call
    /// `ShellEnvironment.warm()` at launch so the cache is ready by the time the
    /// user clicks "Launch Session" — this replaces the previous static-initializer
    /// design that blocked the calling thread for up to 5 seconds on first access.
    ///
    /// Probing strategy:
    /// 1. `zsh -l -i` (login + interactive) — sources .zprofile AND .zshrc,
    ///    which nvm/asdf/mise require. Interactive shells can hang on prompt
    ///    frameworks (oh-my-zsh, powerlevel10k, starship), so we suppress prompts
    ///    via env vars and bound with a 5-second timeout.
    /// 2. If that yields no PATH, fall back to `zsh -l` (login only, 3s timeout).
    /// 3. If both fail, return a hardcoded sane-default PATH; no credentials.
    public enum ShellEnvironment {
        // MARK: - Allowlisted credential keys

        /// Keys to harvest from the login shell. PATH always included;
        /// the rest are AI-provider credentials that GUI apps never see.
        private static let shellEnvKeys: [String] = [
            "PATH",
            "ANTHROPIC_API_KEY", "ANTHROPIC_TOKEN", "ANTHROPIC_BASE_URL",
            "OPENAI_API_KEY", "OPENAI_BASE_URL",
            "OPENROUTER_API_KEY",
            "GEMINI_API_KEY", "GOOGLE_API_KEY",
            "GROQ_API_KEY", "MISTRAL_API_KEY", "XAI_API_KEY",
            "CLAUDE_CODE_OAUTH_TOKEN",
            "HOME", "USER", "LANG", "TERM", "TMPDIR"
        ]

        // MARK: - Public API

        /// Environment dict suitable for Process. Starts from
        /// ProcessInfo.processInfo.environment and overlays shell-harvested
        /// PATH + credential keys. Shell values win for overlapping keys.
        ///
        /// First call triggers an async probe; subsequent callers reuse the cache.
        /// Concurrent callers share the same in-flight probe.
        public static func enrichedEnvironment() async -> [String: String] {
            await Cache.shared.enrichedEnvironment()
        }

        /// Pre-warm the probe in the background. Safe to call multiple times.
        /// Use this at app launch so the cache is ready before any subprocess
        /// invocation needs it.
        public static func warm() {
            Task.detached { _ = await Cache.shared.enrichedEnvironment() }
        }

        // MARK: - Cache actor

        private actor Cache {
            static let shared = Cache()

            private var cached: [String: String]?
            private var inFlight: Task<[String: String], Never>?

            func enrichedEnvironment() async -> [String: String] {
                if let cached { return cached }
                if let inFlight { return await inFlight.value }

                let task = Task { await Self.runFullProbe() }
                inFlight = task
                let result = await task.value
                cached = result
                inFlight = nil
                return result
            }

            private static func runFullProbe() async -> [String: String] {
                let logger = Logger(subsystem: "com.agentboard.modern", category: "ShellEnvironment")
                let script = ShellEnvironment.shellEnvKeys.map { key in
                    "printf '%s\\0%s\\0' \"\(key)\" \"$\(key)\""
                }.joined(separator: "; ")

                // Build the merged base from ProcessInfo + probed values.
                func merge(_ probed: [String: String]) -> [String: String] {
                    var env = ProcessInfo.processInfo.environment
                    for (key, value) in probed where !value.isEmpty {
                        env[key] = value
                    }
                    return env
                }

                // Attempt 1: login + interactive (covers nvm/asdf/mise in .zshrc).
                if let result = await runShellProbe(script: script, interactive: true, timeout: 5.0),
                   result["PATH"] != nil {
                    let pathCount = result["PATH"]?.split(separator: ":").count ?? 0
                    logger.info("Shell probe succeeded (login+interactive): PATH has \(pathCount) entries")
                    return merge(result)
                }

                // Attempt 2: login only (safe fallback if interactive hangs).
                if let result = await runShellProbe(script: script, interactive: false, timeout: 3.0),
                   result["PATH"] != nil {
                    let pathCount = result["PATH"]?.split(separator: ":").count ?? 0
                    logger.info("Shell probe succeeded (login-only): PATH has \(pathCount) entries")
                    return merge(result)
                }

                // Fallback: hardcoded sane-default PATH; no credential env.
                let home = NSHomeDirectory()
                let fallbackPath = [
                    "\(home)/.local/bin",
                    "\(home)/.nvm/versions/node/*/bin",
                    "/opt/homebrew/bin",
                    "/opt/homebrew/sbin",
                    "/usr/local/bin",
                    "/usr/bin",
                    "/bin",
                    "/usr/sbin",
                    "/sbin"
                ].joined(separator: ":")
                logger.warning("Shell probe failed; using hardcoded PATH fallback")
                return merge(["PATH": fallbackPath])
            }

            /// Runs a zsh probe and returns parsed KEY\0VALUE\0 output.
            /// Returns nil on timeout or non-zero exit.
            private static func runShellProbe(
                script: String,
                interactive: Bool,
                timeout: TimeInterval
            ) async -> [String: String]? {
                let arguments: [String] = interactive
                    ? ["-l", "-i", "-c", script]
                    : ["-l", "-c", script]

                let probeEnv: [String: String]?
                if interactive {
                    // Defang prompt frameworks so -i doesn't hang.
                    var env = ProcessInfo.processInfo.environment
                    env["TERM"] = "dumb"
                    env["PS1"] = ""
                    env["PROMPT"] = ""
                    env["RPROMPT"] = ""
                    env["POWERLEVEL9K_INSTANT_PROMPT"] = "off"
                    env["STARSHIP_DISABLE"] = "1"
                    env["ZSH_DISABLE_COMPFIX"] = "true"
                    probeEnv = env
                } else {
                    probeEnv = nil
                }

                let result: ProcessResult
                do {
                    result = try await Process.runAsync(
                        executablePath: "/bin/zsh",
                        arguments: arguments,
                        environment: probeEnv,
                        timeout: timeout
                    )
                } catch {
                    return nil
                }

                guard result.succeeded, !result.stdout.isEmpty else { return nil }

                var parsed: [String: String] = [:]
                let parts = result.stdout.split(separator: 0, omittingEmptySubsequences: false)
                var index = 0
                while index + 1 < parts.count {
                    if let key = String(data: Data(parts[index]), encoding: .utf8),
                       let value = String(data: Data(parts[index + 1]), encoding: .utf8),
                       !key.isEmpty, !value.isEmpty {
                        parsed[key] = value
                    }
                    index += 2
                }
                return parsed.isEmpty ? nil : parsed
            }
        }
    }
#endif
