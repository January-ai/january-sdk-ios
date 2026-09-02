import Combine
import Foundation

/// Records microphone audio and converts it to text with Apple Speech.
///
/// Create one session per voice-enabled input. Observe ``state``, ``audioLevel``,
/// and ``recordingDuration`` to render recording UI, then call
/// ``stopAndTranscribe()`` to obtain the transcript and captured audio file.
///
/// The host app must provide `NSMicrophoneUsageDescription` and
/// `NSSpeechRecognitionUsageDescription` in its Info.plist.
@MainActor
public final class VoiceCaptureSession: ObservableObject {
    /// The current capture lifecycle state.
    @Published public private(set) var state: VoiceCaptureState = .idle
    /// A normalized microphone level from `0` (silent) to `1` (maximum).
    @Published public private(set) var audioLevel: Float = 0
    /// The current recording length in seconds.
    @Published public private(set) var recordingDuration: TimeInterval = 0

    /// Whether the session is requesting access, recording, or transcribing.
    public var isActive: Bool { state != .idle }

    private let permissions: any VoiceCapturePermissionProviding
    private let recorder: any VoiceCaptureRecording
    private let transcriber: any VoiceCaptureTranscribing
    private let recordingURLProvider: () -> URL
    private let fileManager: FileManager
    private var meterCancellable: AnyCancellable?
    private var activeCaptureID: UUID?
    private var activeRecordingURL: URL?
    private var retainedResultURL: URL?

    /// Creates a voice capture session.
    ///
    /// - Parameter locale: The locale used for speech recognition. Pass `nil` to
    ///   use the device's current speech-recognition locale.
    public convenience init(locale: Locale? = nil) {
        self.init(
            permissions: SystemVoiceCapturePermissionProvider(),
            recorder: SystemVoiceCaptureRecorder(),
            transcriber: SystemVoiceCaptureTranscriber(locale: locale),
            recordingURLProvider: {
                FileManager.default.temporaryDirectory
                    .appendingPathComponent("january-voice-\(UUID().uuidString)")
                    .appendingPathExtension("m4a")
            },
            fileManager: .default
        )
    }

    internal init(
        permissions: any VoiceCapturePermissionProviding,
        recorder: any VoiceCaptureRecording,
        transcriber: any VoiceCaptureTranscribing,
        recordingURLProvider: @escaping () -> URL,
        fileManager: FileManager
    ) {
        self.permissions = permissions
        self.recorder = recorder
        self.transcriber = transcriber
        self.recordingURLProvider = recordingURLProvider
        self.fileManager = fileManager
    }

    /// Requests access when necessary and begins recording microphone audio.
    ///
    /// Calling this method while the session is active throws
    /// ``VoiceCaptureError/invalidState``.
    public func startRecording() async throws {
        guard state == .idle else { throw VoiceCaptureError.invalidState }

        let captureID = UUID()
        activeCaptureID = captureID
        state = .requestingPermissions

        do {
            try await permissions.requestPermissions()
        } catch {
            guard activeCaptureID == captureID else { throw VoiceCaptureError.cancelled }
            finishCapture()
            throw error
        }

        guard activeCaptureID == captureID else { throw VoiceCaptureError.cancelled }

        let recordingURL = recordingURLProvider()
        if recordingURL != retainedResultURL {
            try? fileManager.removeItem(at: recordingURL)
        }

        do {
            try recorder.startRecording(to: recordingURL)
        } catch {
            recorder.stopRecording()
            try? fileManager.removeItem(at: recordingURL)
            finishCapture()
            if let voiceError = error as? VoiceCaptureError { throw voiceError }
            throw VoiceCaptureError.recordingFailed(error.localizedDescription)
        }

        if let retainedResultURL, retainedResultURL != recordingURL {
            try? fileManager.removeItem(at: retainedResultURL)
        }
        retainedResultURL = nil

        activeRecordingURL = recordingURL
        audioLevel = 0
        recordingDuration = 0
        state = .recording
        startMetering()
    }

    /// Stops the current recording and transcribes it with Apple Speech.
    ///
    /// The returned audio file remains available until the next recording starts
    /// or this session is deallocated. Copy it elsewhere to retain it longer.
    public func stopAndTranscribe() async throws -> VoiceCaptureResult {
        guard state == .recording,
              let captureID = activeCaptureID,
              let recordingURL = activeRecordingURL else {
            throw VoiceCaptureError.invalidState
        }

        let duration = recorder.currentTime
        stopMetering()
        recorder.stopRecording()
        audioLevel = 0
        recordingDuration = duration
        state = .transcribing

        do {
            let transcript = try await transcriber.transcribe(audioAt: recordingURL)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard activeCaptureID == captureID else { throw VoiceCaptureError.cancelled }
            guard !transcript.isEmpty else { throw VoiceCaptureError.emptyTranscript }

            let result = VoiceCaptureResult(
                transcript: transcript,
                audioURL: recordingURL,
                duration: duration
            )
            retainedResultURL = recordingURL
            finishCapture()
            return result
        } catch {
            guard activeCaptureID == captureID else { throw VoiceCaptureError.cancelled }
            try? fileManager.removeItem(at: recordingURL)
            finishCapture()
            if let voiceError = error as? VoiceCaptureError { throw voiceError }
            throw VoiceCaptureError.transcriptionFailed(error.localizedDescription)
        }
    }

    /// Cancels recording or transcription and removes the in-progress audio file.
    public func cancel() {
        guard state != .idle else { return }
        stopMetering()
        if state == .recording {
            recorder.stopRecording()
        } else if state == .transcribing {
            transcriber.cancel()
        }
        if let activeRecordingURL {
            try? fileManager.removeItem(at: activeRecordingURL)
        }
        finishCapture()
    }

    private func startMetering() {
        meterCancellable?.cancel()
        meterCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
            guard let self, self.state == .recording else { return }
            self.audioLevel = Self.normalizedLevel(decibels: self.recorder.averagePower)
            self.recordingDuration = self.recorder.currentTime
        }
    }

    private func stopMetering() {
        meterCancellable?.cancel()
        meterCancellable = nil
    }

    private func finishCapture() {
        stopMetering()
        activeCaptureID = nil
        activeRecordingURL = nil
        audioLevel = 0
        recordingDuration = 0
        state = .idle
    }

    nonisolated internal static func normalizedLevel(decibels: Float) -> Float {
        let minimumDecibels: Float = -50
        guard decibels.isFinite, decibels > minimumDecibels else { return 0 }
        guard decibels < 0 else { return 1 }
        return (decibels - minimumDecibels) / -minimumDecibels
    }

    deinit {
        meterCancellable?.cancel()
        if let activeRecordingURL {
            try? fileManager.removeItem(at: activeRecordingURL)
        }
        if let retainedResultURL {
            try? fileManager.removeItem(at: retainedResultURL)
        }
    }
}

@MainActor
internal protocol VoiceCapturePermissionProviding: AnyObject {
    func requestPermissions() async throws
}

@MainActor
internal protocol VoiceCaptureRecording: AnyObject {
    var averagePower: Float { get }
    var currentTime: TimeInterval { get }
    func startRecording(to url: URL) throws
    func stopRecording()
}

@MainActor
internal protocol VoiceCaptureTranscribing: AnyObject {
    func transcribe(audioAt url: URL) async throws -> String
    func cancel()
}
