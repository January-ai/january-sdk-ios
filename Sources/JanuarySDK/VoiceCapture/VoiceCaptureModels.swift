import Foundation

/// The lifecycle state of a ``VoiceCaptureSession``.
public enum VoiceCaptureState: Equatable, Sendable {
    /// No recording or transcription is in progress.
    case idle
    /// The SDK is requesting microphone and speech-recognition access.
    case requestingPermissions
    /// Audio is being recorded from the microphone.
    case recording
    /// The completed recording is being transcribed with Apple Speech.
    case transcribing
}

/// A completed voice capture and its Apple Speech transcript.
public struct VoiceCaptureResult: Equatable, Sendable {
    /// The recognized text, trimmed of leading and trailing whitespace.
    public let transcript: String
    /// The length of the recording in seconds.
    public let duration: TimeInterval

    public init(transcript: String, duration: TimeInterval) {
        self.transcript = transcript
        self.duration = duration
    }
}

/// Errors produced while requesting access, recording, or transcribing audio.
public enum VoiceCaptureError: Error, Equatable, LocalizedError, Sendable {
    /// The app is missing a required privacy usage description in its Info.plist.
    case missingUsageDescription(String)
    /// The user denied microphone access.
    case microphonePermissionDenied
    /// The user denied or is restricted from using speech recognition.
    case speechRecognitionPermissionDenied
    /// Speech recognition is temporarily unavailable for the selected locale.
    case speechRecognizerUnavailable
    /// The microphone recording could not be started.
    case recordingFailed(String)
    /// Apple Speech could not transcribe the recording.
    case transcriptionFailed(String)
    /// Speech recognition completed without recognizing any text.
    case emptyTranscript
    /// The requested operation does not match the session's current state.
    case invalidState
    /// The current capture was cancelled.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .missingUsageDescription(let key):
            return "Add \(key) to the app's Info.plist before using voice capture."
        case .microphonePermissionDenied:
            return "Microphone access is required to capture voice input."
        case .speechRecognitionPermissionDenied:
            return "Speech recognition access is required to transcribe voice input."
        case .speechRecognizerUnavailable:
            return "Speech recognition is not currently available."
        case .recordingFailed(let message):
            return "Voice recording could not start. \(message)"
        case .transcriptionFailed(let message):
            return "The recording could not be transcribed. \(message)"
        case .emptyTranscript:
            return "No speech was recognized. Please try again."
        case .invalidState:
            return "Voice capture is not ready for that operation."
        case .cancelled:
            return "Voice capture was cancelled."
        }
    }
}
