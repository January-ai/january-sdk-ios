import January
import SwiftUI
import UIKit

struct SearchField: View {
    let prompt: String
    @Binding var text: String
    var voiceCaptureEnabled = true
    var submit: (() -> Void)?

    @Environment(\.openURL) private var openURL
    @StateObject private var voiceCapture = VoiceCaptureSession()
    @State private var voiceAlert: VoiceCaptureAlert?

    var body: some View {
        Group {
            switch voiceCapture.state {
            case .idle:
                searchContent
            case .requestingPermissions:
                statusContent(label: "Starting microphone…")
            case .recording:
                recordingContent
            case .transcribing:
                statusContent(label: "Transcribing…")
            }
        }
        .padding(.horizontal, AppSpacing.controlHorizontal)
        .frame(minHeight: 56)
        .background(AppPalette.control, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: voiceCapture.state)
        .alert(item: $voiceAlert) { alert in
            if alert.opensSettings {
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Settings")) {
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            openURL(settingsURL)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            return Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: voiceCaptureEnabled) { _, isEnabled in
            if !isEnabled { voiceCapture.cancel() }
        }
        .onDisappear {
            voiceCapture.cancel()
        }
    }

    private var searchContent: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(AppPalette.muted)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(AppTypography.body)
                .submitLabel(.search)
                .onSubmit { submit?() }

            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(AppPalette.subdued)
            }

            if voiceCaptureEnabled {
                Button("Use voice input", systemImage: "mic.fill") {
                    startVoiceCapture()
                }
                .labelStyle(.iconOnly)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppPalette.green)
                .frame(width: 36, height: 36)
                .accessibilityIdentifier("voice-capture-button")
            }
        }
    }

    private var recordingContent: some View {
        HStack(spacing: 12) {
            cancelButton

            VoiceLevelMeter(level: voiceCapture.audioLevel)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

            Text(formatDuration(voiceCapture.recordingDuration))
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(AppPalette.body)
                .accessibilityLabel("Recording duration \(formatDuration(voiceCapture.recordingDuration))")

            Button {
                stopAndTranscribe()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(AppPalette.green, in: Circle())
            }
            .labelStyle(.iconOnly)
            .accessibilityLabel("Stop and transcribe")
        }
    }

    private func statusContent(label: String) -> some View {
        HStack(spacing: 12) {
            cancelButton
            Spacer()
            ProgressView()
                .tint(AppPalette.green)
            Text(label)
                .font(AppTypography.body)
                .foregroundStyle(AppPalette.muted)
            Spacer()
        }
    }

    private var cancelButton: some View {
        Button("Cancel voice input", systemImage: "xmark") {
            voiceCapture.cancel()
        }
        .labelStyle(.iconOnly)
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(AppPalette.muted)
        .frame(width: 36, height: 36)
    }

    private func startVoiceCapture() {
        Task {
            do {
                try await voiceCapture.startRecording()
            } catch VoiceCaptureError.cancelled {
                return
            } catch {
                present(error)
            }
        }
    }

    private func stopAndTranscribe() {
        Task {
            do {
                let result = try await voiceCapture.stopAndTranscribe()
                text += (text.isEmpty ? "" : " ") + result.transcript
            } catch VoiceCaptureError.cancelled {
                return
            } catch {
                present(error)
            }
        }
    }

    private func present(_ error: Error) {
        switch error as? VoiceCaptureError {
        case .microphonePermissionDenied:
            voiceAlert = .microphonePermissionDenied
        case .speechRecognitionPermissionDenied:
            voiceAlert = .speechRecognitionPermissionDenied
        default:
            voiceAlert = .failure(error.localizedDescription)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(0, Int(duration))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private enum VoiceCaptureAlert: Identifiable {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case failure(String)

    var id: String {
        switch self {
        case .microphonePermissionDenied: "microphone-permission-denied"
        case .speechRecognitionPermissionDenied: "speech-recognition-permission-denied"
        case .failure(let message): "failure-\(message)"
        }
    }

    var title: String {
        switch self {
        case .microphonePermissionDenied:
            "Microphone Access Denied"
        case .speechRecognitionPermissionDenied:
            "Speech Recognition Access Denied"
        case .failure:
            "Voice input unavailable"
        }
    }

    var message: String {
        switch self {
        case .microphonePermissionDenied:
            "Please enable microphone access in Settings."
        case .speechRecognitionPermissionDenied:
            "Please enable speech recognition access in Settings."
        case .failure(let message):
            message
        }
    }

    var opensSettings: Bool {
        switch self {
        case .microphonePermissionDenied, .speechRecognitionPermissionDenied: true
        case .failure: false
        }
    }
}

private struct VoiceLevelMeter: View {
    let level: Float
    private let barWeights: [CGFloat] = [0.45, 0.8, 0.6, 1, 0.7, 0.9, 0.5, 0.75]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(barWeights.enumerated()), id: \.offset) { _, weight in
                Capsule()
                    .fill(AppPalette.green)
                    .frame(width: 3, height: max(4, 28 * CGFloat(level) * weight))
            }
        }
        .frame(height: 30)
        .animation(.linear(duration: 0.05), value: level)
    }
}

private struct SearchFieldPreview: View {
    @State private var text = "pizza"
    var body: some View { SearchField(prompt: "Food name", text: $text) }
}

#Preview {
    SearchFieldPreview()
        .padding()
        .background(AppPalette.paper)
}
