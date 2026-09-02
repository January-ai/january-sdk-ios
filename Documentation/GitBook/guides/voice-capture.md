# Voice capture

`VoiceCaptureSession` records AAC audio from the microphone and transcribes it
with Apple Speech. It does not call January's servers and does
not require a `JanuaryClient` or authentication.

## Add privacy descriptions

Add both purpose strings to the host app's `Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Use your voice to enter food and meal searches.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Turn your recorded voice into search text.</string>
```

The SDK checks for both entries before requesting access. Missing configuration
throws `VoiceCaptureError.missingUsageDescription`.

## Capture and transcribe

Keep one session alive for each voice-enabled input. Observe its published state
to show the microphone, recording, and transcription UI that fits your app:

```swift
import January
import SwiftUI
import UIKit

struct VoiceSearchField: View {
    @Binding var query: String
    @Environment(\.openURL) private var openURL
    @StateObject private var voiceCapture = VoiceCaptureSession()
    @State private var errorMessage: String?
    @State private var showPermissionAlert = false

    var body: some View {
        HStack {
            TextField("Search foods", text: $query)

            switch voiceCapture.state {
            case .idle:
                Button("Use voice input", systemImage: "mic.fill") {
                    Task {
                        do {
                            try await voiceCapture.startRecording()
                        } catch VoiceCaptureError.microphonePermissionDenied,
                                VoiceCaptureError.speechRecognitionPermissionDenied {
                            showPermissionAlert = true
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            case .recording:
                Text(voiceCapture.recordingDuration, format: .number.precision(.fractionLength(0)))
                Button("Stop", systemImage: "stop.fill") {
                    Task {
                        do {
                            let result = try await voiceCapture.stopAndTranscribe()
                            query += (query.isEmpty ? "" : " ") + result.transcript
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                }
            case .requestingPermissions, .transcribing:
                ProgressView()
                Button("Cancel") { voiceCapture.cancel() }
            }
        }
        .alert("Microphone Access Denied", isPresented: $showPermissionAlert) {
            Button("Settings") {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone and speech recognition access in Settings.")
        }
    }
}
```

`audioLevel` is normalized from `0...1` for waveform or level-meter UI.
`recordingDuration` reports the current length in seconds.

Permission prompts appear only on the first request. If the user has already
denied microphone or Speech access, present an alert with a Settings action as
shown above; iOS will not display the system prompt again. Keep other recording
and transcription failures on a normal retryable error path rather than sending
the user to Settings.

## Captured audio lifecycle

`stopAndTranscribe()` returns a `VoiceCaptureResult` containing the transcript,
and recording duration. The SDK deletes its temporary AAC file immediately after
Apple Speech finishes transcription, before `stopAndTranscribe()` returns. It
also deletes the file after failed or cancelled transcription.

Call `cancel()` while recording or transcribing to stop work and delete the
in-progress file. Permission denial, unavailable speech recognition, an empty
transcript, and recording or transcription failures are represented by stable
`VoiceCaptureError` cases.
