import Foundation
import Testing
@testable import January

@MainActor
private final class StubVoicePermissions: VoiceCapturePermissionProviding {
    var result: Result<Void, Error> = .success(())
    private(set) var requestCount = 0

    func requestPermissions() async throws {
        requestCount += 1
        try result.get()
    }
}

@MainActor
private final class SuspendedVoicePermissions: VoiceCapturePermissionProviding {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isWaiting = false

    func requestPermissions() async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            isWaiting = true
        }
    }

    func grant() {
        continuation?.resume()
        continuation = nil
        isWaiting = false
    }
}

@MainActor
private final class StubVoiceRecorder: VoiceCaptureRecording {
    var averagePower: Float = -25
    var currentTime: TimeInterval = 2.75
    var startError: Error?
    private(set) var startedURLs: [URL] = []
    private(set) var stopCount = 0

    func startRecording(to url: URL) throws {
        if let startError { throw startError }
        startedURLs.append(url)
    }

    func stopRecording() {
        stopCount += 1
    }
}

@MainActor
private final class StubVoiceTranscriber: VoiceCaptureTranscribing {
    var result: Result<String, Error> = .success("greek yogurt")
    private(set) var transcribedURLs: [URL] = []
    private(set) var fileExistedDuringTranscription = false
    private(set) var cancelCount = 0

    func transcribe(audioAt url: URL) async throws -> String {
        transcribedURLs.append(url)
        fileExistedDuringTranscription = FileManager.default.fileExists(atPath: url.path)
        return try result.get()
    }

    func cancel() {
        cancelCount += 1
    }
}

@MainActor
private final class SuspendedVoiceTranscriber: VoiceCaptureTranscribing {
    private var continuation: CheckedContinuation<String, Error>?
    private(set) var isWaiting = false

    func transcribe(audioAt url: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            isWaiting = true
        }
    }

    func cancel() {
        continuation?.resume(throwing: VoiceCaptureError.cancelled)
        continuation = nil
        isWaiting = false
    }

    func complete(with transcript: String) {
        continuation?.resume(returning: transcript)
        continuation = nil
        isWaiting = false
    }
}

@MainActor
private func makeSession(
    permissions: StubVoicePermissions? = nil,
    recorder: StubVoiceRecorder? = nil,
    transcriber: StubVoiceTranscriber? = nil,
    url: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("voice-capture-test-\(UUID().uuidString).m4a")
) -> VoiceCaptureSession {
    VoiceCaptureSession(
        permissions: permissions ?? StubVoicePermissions(),
        recorder: recorder ?? StubVoiceRecorder(),
        transcriber: transcriber ?? StubVoiceTranscriber(),
        recordingURLProvider: { url },
        fileManager: .default
    )
}

@Test @MainActor
func voiceCaptureRecordsAndReturnsTrimmedTranscript() async throws {
    let recorder = StubVoiceRecorder()
    let transcriber = StubVoiceTranscriber()
    transcriber.result = .success("  greek yogurt  ")
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("successful-voice-capture-\(UUID().uuidString).m4a")
    let session = makeSession(recorder: recorder, transcriber: transcriber, url: url)

    try await session.startRecording()
    #expect(session.state == .recording)
    #expect(session.isActive)
    #expect(recorder.startedURLs == [url])
    try Data([1]).write(to: url)

    let result = try await session.stopAndTranscribe()

    #expect(result == VoiceCaptureResult(transcript: "greek yogurt", duration: 2.75))
    #expect(recorder.stopCount == 1)
    #expect(transcriber.transcribedURLs == [url])
    #expect(transcriber.fileExistedDuringTranscription)
    #expect(!FileManager.default.fileExists(atPath: url.path))
    #expect(session.state == .idle)
    #expect(!session.isActive)
}

@Test @MainActor
func permissionFailureReturnsSessionToIdle() async {
    let permissions = StubVoicePermissions()
    permissions.result = .failure(VoiceCaptureError.microphonePermissionDenied)
    let recorder = StubVoiceRecorder()
    let session = makeSession(permissions: permissions, recorder: recorder)

    await #expect(throws: VoiceCaptureError.microphonePermissionDenied) {
        try await session.startRecording()
    }

    #expect(session.state == .idle)
    #expect(recorder.startedURLs.isEmpty)
}

@Test @MainActor
func cancellingPermissionTaskDoesNotStartRecording() async throws {
    let permissions = SuspendedVoicePermissions()
    let recorder = StubVoiceRecorder()
    let session = VoiceCaptureSession(
        permissions: permissions,
        recorder: recorder,
        transcriber: StubVoiceTranscriber(),
        recordingURLProvider: {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("cancel-permission-\(UUID().uuidString).m4a")
        },
        fileManager: .default
    )

    let start = Task { @MainActor in
        try await session.startRecording()
    }
    for _ in 0..<100 where !permissions.isWaiting {
        await Task.yield()
    }
    try #require(permissions.isWaiting)

    start.cancel()
    permissions.grant()

    await #expect(throws: VoiceCaptureError.cancelled) {
        try await start.value
    }
    #expect(recorder.startedURLs.isEmpty)
    #expect(session.state == .idle)
}

@Test @MainActor
func cancelStopsAndDiscardsActiveCapture() async throws {
    let recorder = StubVoiceRecorder()
    let transcriber = StubVoiceTranscriber()
    let session = makeSession(recorder: recorder, transcriber: transcriber)

    try await session.startRecording()
    session.cancel()

    #expect(recorder.stopCount == 1)
    #expect(transcriber.cancelCount == 0)
    #expect(session.state == .idle)
}

@Test @MainActor
func deinitializingAnActiveSessionStopsAndDeletesTheRecording() async throws {
    let recorder = StubVoiceRecorder()
    let transcriber = StubVoiceTranscriber()
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("deinit-voice-capture-\(UUID().uuidString).m4a")
    var session: VoiceCaptureSession? = makeSession(recorder: recorder, transcriber: transcriber, url: url)

    try await session?.startRecording()
    try Data([1]).write(to: url)
    session = nil
    for _ in 0..<100 where recorder.stopCount == 0 {
        await Task.yield()
    }

    #expect(recorder.stopCount == 1)
    #expect(transcriber.cancelCount == 1)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test @MainActor
func cancelResumesAnInFlightTranscription() async throws {
    let transcriber = SuspendedVoiceTranscriber()
    let session = VoiceCaptureSession(
        permissions: StubVoicePermissions(),
        recorder: StubVoiceRecorder(),
        transcriber: transcriber,
        recordingURLProvider: {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("cancel-transcription-\(UUID().uuidString).m4a")
        },
        fileManager: .default
    )

    try await session.startRecording()
    let transcription = Task { @MainActor in
        try await session.stopAndTranscribe()
    }
    for _ in 0..<100 where !transcriber.isWaiting {
        await Task.yield()
    }
    try #require(transcriber.isWaiting)

    #expect(session.state == .transcribing)
    session.cancel()
    await #expect(throws: VoiceCaptureError.cancelled) {
        try await transcription.value
    }
    #expect(session.state == .idle)
}

@Test @MainActor
func cancellingTranscriptionTaskDeletesRecordingAndReturnsToIdle() async throws {
    let transcriber = SuspendedVoiceTranscriber()
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("task-cancel-transcription-\(UUID().uuidString).m4a")
    let session = VoiceCaptureSession(
        permissions: StubVoicePermissions(),
        recorder: StubVoiceRecorder(),
        transcriber: transcriber,
        recordingURLProvider: { url },
        fileManager: .default
    )

    try await session.startRecording()
    try Data([1]).write(to: url)
    let transcription = Task { @MainActor in
        try await session.stopAndTranscribe()
    }
    for _ in 0..<100 where !transcriber.isWaiting {
        await Task.yield()
    }
    try #require(transcriber.isWaiting)

    transcription.cancel()
    transcriber.complete(with: "greek yogurt")

    await #expect(throws: VoiceCaptureError.cancelled) {
        try await transcription.value
    }
    #expect(session.state == .idle)
    #expect(!FileManager.default.fileExists(atPath: url.path))
}

@Test @MainActor
func emptyTranscriptIsReportedAndSessionCanRecordAgain() async throws {
    let transcriber = StubVoiceTranscriber()
    transcriber.result = .success("   ")
    let session = makeSession(transcriber: transcriber)

    try await session.startRecording()
    await #expect(throws: VoiceCaptureError.emptyTranscript) {
        try await session.stopAndTranscribe()
    }
    #expect(session.state == .idle)

    try await session.startRecording()
    #expect(session.state == .recording)
    session.cancel()
}

@Test @MainActor
func invalidOperationsDoNotChangeState() async {
    let session = makeSession()

    await #expect(throws: VoiceCaptureError.invalidState) {
        try await session.stopAndTranscribe()
    }
    #expect(session.state == .idle)
}

@Test
func voiceLevelNormalizationMatchesRecordingMeterRange() {
    #expect(VoiceCaptureSession.normalizedLevel(decibels: -.infinity) == 0)
    #expect(VoiceCaptureSession.normalizedLevel(decibels: -60) == 0)
    #expect(VoiceCaptureSession.normalizedLevel(decibels: -25) == 0.5)
    #expect(VoiceCaptureSession.normalizedLevel(decibels: 0) == 1)
}

@Test
func voiceCaptureErrorsHavePartnerFacingDescriptions() {
    let errors: [VoiceCaptureError] = [
        .missingUsageDescription("NSMicrophoneUsageDescription"),
        .microphonePermissionDenied,
        .speechRecognitionPermissionDenied,
        .speechRecognizerUnavailable,
        .recordingFailed("Recorder unavailable."),
        .transcriptionFailed("Recognizer unavailable."),
        .emptyTranscript,
        .invalidState,
        .cancelled,
    ]

    for error in errors {
        #expect(!(error.errorDescription ?? "").isEmpty)
    }
}
