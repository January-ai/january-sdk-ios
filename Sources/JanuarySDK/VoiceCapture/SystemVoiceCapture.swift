import AVFoundation
import Foundation
import Speech

@MainActor
internal final class SystemVoiceCapturePermissionProvider: VoiceCapturePermissionProviding {
    func requestPermissions() async throws {
        try validateUsageDescription("NSMicrophoneUsageDescription")
        try validateUsageDescription("NSSpeechRecognitionUsageDescription")

        guard await requestMicrophonePermission() else {
            throw VoiceCaptureError.microphonePermissionDenied
        }
        guard await requestSpeechRecognitionPermission() else {
            throw VoiceCaptureError.speechRecognitionPermissionDenied
        }
    }

    private func validateUsageDescription(_ key: String) throws {
        let description = Bundle.main.object(forInfoDictionaryKey: key) as? String
        guard let description,
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw VoiceCaptureError.missingUsageDescription(key)
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            return await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }

    private func requestSpeechRecognitionPermission() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        @unknown default:
            return false
        }
    }
}

@MainActor
internal final class SystemVoiceCaptureRecorder: VoiceCaptureRecording {
    private let audioSession = AVAudioSession.sharedInstance()
    private var audioRecorder: AVAudioRecorder?

    var averagePower: Float {
        guard let audioRecorder else { return -160 }
        audioRecorder.updateMeters()
        return audioRecorder.averagePower(forChannel: 0)
    }

    var currentTime: TimeInterval { audioRecorder?.currentTime ?? 0 }

    func startRecording(to url: URL) throws {
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth])
        try audioSession.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        guard recorder.record() else {
            throw VoiceCaptureError.recordingFailed("The audio recorder did not start.")
        }
        audioRecorder = recorder
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }

    deinit {
        audioRecorder?.stop()
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    }
}

@MainActor
internal final class SystemVoiceCaptureTranscriber: VoiceCaptureTranscribing {
    private let recognizer: SFSpeechRecognizer?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuationBox: SpeechRecognitionContinuationBox?

    init(locale: Locale?) {
        recognizer = locale.map(SFSpeechRecognizer.init(locale:)) ?? SFSpeechRecognizer()
    }

    func transcribe(audioAt url: URL) async throws -> String {
        guard let recognizer, recognizer.isAvailable else {
            throw VoiceCaptureError.speechRecognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        let box = SpeechRecognitionContinuationBox()
        continuationBox = box

        do {
            let transcript = try await withCheckedThrowingContinuation { continuation in
                box.store(continuation)
                recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        box.resume(throwing: VoiceCaptureError.transcriptionFailed(error.localizedDescription))
                    } else if let result, result.isFinal {
                        box.resume(returning: result.bestTranscription.formattedString)
                    }
                }
            }
            recognitionTask = nil
            continuationBox = nil
            return transcript
        } catch {
            recognitionTask = nil
            continuationBox = nil
            throw error
        }
    }

    func cancel() {
        recognitionTask?.cancel()
        continuationBox?.resume(throwing: VoiceCaptureError.cancelled)
        recognitionTask = nil
        continuationBox = nil
    }

    deinit {
        recognitionTask?.cancel()
        continuationBox?.resume(throwing: VoiceCaptureError.cancelled)
    }
}

private final class SpeechRecognitionContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var result: Result<String, Error>?

    func store(_ continuation: CheckedContinuation<String, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func resume(returning transcript: String) {
        resume(with: .success(transcript))
    }

    func resume(throwing error: Error) {
        resume(with: .failure(error))
    }

    private func resume(with result: Result<String, Error>) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
