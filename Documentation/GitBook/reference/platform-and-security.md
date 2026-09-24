# Platform and security

## Platforms

Every SDK feature, including the food scanner and voice capture, runs on iOS 15 and later ([requirements](../README.md#requirements)). The SDK doesn't support macOS, Mac Catalyst, tvOS, watchOS, or visionOS.

## Credentials

* Keep your API key on your backend. The only exception is [local development](../getting-started/authentication.md#local-development) in a Debug build.
* The SDK keeps client tokens in memory. Don't write them to disk or logs.
* Configure your token endpoint's URL explicitly; don't ship a fallback URL.
* Authenticate the token request with the app's existing session. The [token endpoint rules](https://docs.january.ai/docs/authentication#your-token-endpoint) cover the backend side.
* Create a new client when a different account signs in ([Client lifecycle](../concepts/client-lifecycle.md)).

## User and health data

Meal photos, food logs, glucose profiles, CGM readings, and predictions can be sensitive. Collect and keep as little as you can, get the permissions your product needs, and keep these values out of analytics and crash reports. Use opaque end-user IDs, never email addresses or names.

## Camera privacy

The food scanner needs `NSCameraUsageDescription`. Write a purpose string that matches the feature, and don't ask for camera access before the user starts scanning.

## Microphone and speech privacy

Voice capture needs both `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`. `VoiceCaptureSession` asks for access only when you call `startRecording()`. Recorded audio stays in a temporary local file only while Apple Speech transcribes it; then the SDK deletes the file. The SDK doesn't send audio or transcripts to January.
