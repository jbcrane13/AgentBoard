import SwiftUI

/// Step-by-step pairing guide shown when the gateway returns a pairingRequired error.
struct PairingGuideView: View {
    @Environment(AppState.self) private var appState

    private var deviceId: String {
        DeviceIdentity.loadOrCreate().deviceId
    }

    private var approveCommand: String {
        "openclaw devices approve \(String(deviceId.prefix(12)))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Device Pairing Required", systemImage: "lock.shield")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)

            Text("This device needs to be approved by the gateway before it can connect. Follow these steps on the machine running OpenClaw:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                stepView(number: 1, text: "Open a terminal on the gateway machine")

                stepView(number: 2, text: "Run the approval command:")

                HStack(spacing: 8) {
                    Text(approveCommand)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(approveCommand, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderless)
                    .help("Copy command")
                }
                .padding(.leading, 24)

                stepView(number: 3, text: "Click Retry below to reconnect")
            }

            HStack(spacing: 6) {
                Text("Device ID:")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                Text(String(deviceId.prefix(12)) + "…")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }

            Button {
                appState.retryConnection()
            } label: {
                Label("Retry Connection", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)
        }
        .padding(14)
        .background(Color.red.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    private func stepView(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.red.opacity(0.7), in: Circle())

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
        }
    }
}
