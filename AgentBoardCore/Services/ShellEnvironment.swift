import Foundation
import os

#if os(macOS)

    /// Harvests PATH and allowlisted credential env vars from the user's login
    /// shell so that subprocesses (tmux sessions, ralphy, etc.) can find
    /// Homebrew-managed tools like `node`, `nvm`, `ralphy`, `claude`, `codex`.
    ///
    /// Probing strategy:
    /// 1. `zsh -l -i` (login + interactive) — sources .zprofile AND .zshrc,
    ///    which nvm/asdf/mise require. Interactive shells can hang on prompt
    ///    frameworks (oh-my-zsh, powerlevel10k, starship), so we suppress prompts
    ///    via env vars and bound with a 5-second timeout.
    /// 2. If that yields no PATH, fall back to `zsh -l` (login only, 3s timeout).
    /// 3. If both fail, return a hardcoded sane-default PATH; no credentials.
    enum ShellEnvironment {
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

        // MARK: - Cached enriched env

        /// Cached result — computed once at first access, then reused.
        private static let enrichedShellEnv: [String: String] = {
            let logger = Logger(subsystem: "com.agentboard.modern", category: "ShellEnvironment")

            // Build a shell script that prints KEY\0VALUE\0 for each key.
            let script = shellEnvKeys.map { key in
                "printf '%s\\0%s\\0' \"\(key)\" \"$\(key)\""
            }.joined(separator: "; ")

            // Attempt 1: login + interactive (covers nvm/asdf/mise in .zshrc).
            if let result = runShellProbe(script: script, interactive: true, timeout: 5.0),
               result["PATH"] != nil {
                let pathCount = result["PATH"]?.split(separator: ":").count ?? 0
                logger.info("Shell probe succeeded (login+interactive): PATH has \(pathCount) entries")
                return result
            }

            // Attempt 2: login only (safe fallback if interactive hangs).
            if let result = runShellProbe(script: script, interactive: false, timeout: 3.0),
               result["PATH"] != nil {
                let pathCount = result["PATH"]?.split(separator: ":").count ?? 0
                logger.info("Shell probe succeeded (login-only): PATH has \(pathCount) entries")
                return result
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
            return ["PATH": fallbackPath]
        }()

        // MARK: - Public API

        /// Environment dict suitable for Process.environment. Starts from
        /// ProcessInfo.processInfo.environment and overlays the shell-harvested
        /// PATH and credential keys. Shell values win for overlapping keys.
        nonisolated static func enrichedEnvironment() -> [String: String] {
            var env = ProcessInfo.processInfo.environment
            for (key, value) in enrichedShellEnv where !value.isEmpty {
                env[key] = value
            }
            return env
        }

        // MARK: - Shell probe implementation

        /// Runs a zsh probe and returns parsed KEY\0VALUE\0 output.
        /// Returns nil on timeout or non-zero exit.
        private static func runShellProbe(
            script: String,
            interactive: Bool,
            timeout: TimeInterval
        ) -> [String: String]? {
            let pipe = Pipe()
            let errPipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = interactive
                ? ["-l", "-i", "-c", script]
                : ["-l", "-c", script]
            process.standardOutput = pipe
            process.standardError = errPipe

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
                process.environment = env
            }

            do {
                try process.run()
                let deadline = Date().addingTimeInterval(timeout)
                while process.isRunning && Date() < deadline {
                    Thread.sleep(forTimeInterval: 0.05)
                }
                if process.isRunning {
                    process.terminate()
                    Thread.sleep(forTimeInterval: 0.1)
                    return nil
                }
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard process.terminationStatus == 0, !data.isEmpty else { return nil }

                var result: [String: String] = [:]
                let parts = data.split(separator: 0, omittingEmptySubsequences: false)
                var i = 0
                while i + 1 < parts.count {
                    if let key = String(data: Data(parts[i]), encoding: .utf8),
                       let value = String(data: Data(parts[i + 1]), encoding: .utf8),
                       !key.isEmpty, !value.isEmpty {
                        result[key] = value
                    }
                    i += 2
                }
                return result.isEmpty ? nil : result
            } catch {
                return nil
            }
        }
    }
#endif
