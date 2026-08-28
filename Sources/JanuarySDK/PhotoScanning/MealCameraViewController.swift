@preconcurrency import AVFoundation
import Dispatch
import Foundation
import OSLog
import SwiftUI
import UIKit

private let foodScannerLogger = Logger(
    subsystem: "ai.january.partner-sdk",
    category: "FoodScanner"
)

struct MealCameraRepresentable: UIViewControllerRepresentable {
    let configuration: JanuaryFoodScannerConfiguration
    let isProcessing: Bool
    let onImage: @MainActor (UIImage) -> Void
    let onBarcode: @MainActor (String) -> Void
    let onCancel: @MainActor () -> Void

    func makeUIViewController(context: Context) -> MealCameraViewController {
        MealCameraViewController(
            configuration: configuration,
            onImage: onImage,
            onBarcode: onBarcode,
            onCancel: onCancel
        )
    }

    func updateUIViewController(_ controller: MealCameraViewController, context: Context) {
        controller.setProcessing(isProcessing)
    }
}

@MainActor
private final class MealCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    func setSession(_ session: AVCaptureSession) {
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        foodScannerLogger.info(
            "Camera preview attached before capture start; bounds=\(String(describing: self.bounds), privacy: .public), connection=\(self.previewLayer.connection != nil, privacy: .public)"
        )
    }
}

private final class MealCaptureDelegateProxy: NSObject,
    AVCapturePhotoCaptureDelegate,
    AVCaptureMetadataOutputObjectsDelegate,
    @unchecked Sendable
{
    private let onImage: @MainActor @Sendable (UIImage) -> Void
    private let onBarcode: @MainActor @Sendable (String) -> Void

    init(
        onImage: @escaping @MainActor @Sendable (UIImage) -> Void,
        onBarcode: @escaping @MainActor @Sendable (String) -> Void
    ) {
        self.onImage = onImage
        self.onBarcode = onBarcode
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else { return }
        Task { @MainActor [onImage] in onImage(image) }
    }

    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let value = metadataObjects
            .compactMap({ $0 as? AVMetadataMachineReadableCodeObject })
            .compactMap(\.stringValue)
            .first(where: { !$0.isEmpty })
        else { return }
        Task { @MainActor [onBarcode] in onBarcode(value) }
    }
}

private enum MealCameraAuthorization: Sendable {
    case authorized
    case denied
    case restricted
}

private enum MealCameraServiceError: Error {
    case cameraUnavailable
    case inputUnavailable
    case outputUnavailable
}

private struct MealCameraConfigurationResult: Sendable {
    let cameraName: String
    let cameraIsConnected: Bool
    let cameraHasTorch: Bool
    let inputCount: Int
    let outputCount: Int
}

/// Owns every capture-session and camera-device operation on one serial queue.
private final class MealCameraSessionRunner: @unchecked Sendable {
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let metadataQueue = DispatchQueue(label: "ai.january.partner-sdk.camera-metadata")
    private let sessionQueue = DispatchQueue(label: "ai.january.partner-sdk.camera-session")
    private var camera: AVCaptureDevice?

    static func authorize() async -> MealCameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video) ? .authorized : .denied
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        @unknown default:
            return .restricted
        }
    }

    func configure(
        enabledModes: Set<JanuaryFoodScannerMode>,
        delegate: MealCaptureDelegateProxy
    ) async throws -> MealCameraConfigurationResult {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                do {
                    guard let camera = AVCaptureDevice.default(
                        .builtInWideAngleCamera,
                        for: .video,
                        position: .back
                    ) else {
                        throw MealCameraServiceError.cameraUnavailable
                    }

                    let input: AVCaptureDeviceInput
                    do {
                        input = try AVCaptureDeviceInput(device: camera)
                    } catch {
                        throw MealCameraServiceError.inputUnavailable
                    }

                    session.beginConfiguration()
                    defer { session.commitConfiguration() }

                    if session.canSetSessionPreset(.photo) {
                        session.sessionPreset = .photo
                    }
                    guard session.canAddInput(input) else {
                        throw MealCameraServiceError.inputUnavailable
                    }
                    session.addInput(input)

                    if enabledModes.contains(.photo) {
                        guard session.canAddOutput(photoOutput) else {
                            throw MealCameraServiceError.outputUnavailable
                        }
                        session.addOutput(photoOutput)
                    }

                    if enabledModes.contains(.barcode) {
                        guard session.canAddOutput(metadataOutput) else {
                            throw MealCameraServiceError.outputUnavailable
                        }
                        session.addOutput(metadataOutput)
                        let desired: [AVMetadataObject.ObjectType] = [
                            .upce, .ean8, .ean13, .code39, .code128,
                        ]
                        metadataOutput.metadataObjectTypes = desired.filter(
                            metadataOutput.availableMetadataObjectTypes.contains
                        )
                        metadataOutput.setMetadataObjectsDelegate(delegate, queue: metadataQueue)
                    }

                    self.camera = camera
                    continuation.resume(returning: MealCameraConfigurationResult(
                        cameraName: camera.localizedName,
                        cameraIsConnected: camera.isConnected,
                        cameraHasTorch: camera.hasTorch,
                        inputCount: session.inputs.count,
                        outputCount: session.outputs.count
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                defer { continuation.resume() }
                guard !session.isRunning else { return }
                guard !session.isInterrupted else {
                    foodScannerLogger.info("Capture start deferred while the session is interrupted")
                    return
                }
                foodScannerLogger.info("Starting capture session on camera queue")
                session.startRunning()
                foodScannerLogger.info(
                    "Capture session start completed; running=\(session.isRunning, privacy: .public), interrupted=\(session.isInterrupted, privacy: .public)"
                )
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [session] in
                defer { continuation.resume() }
                guard session.isRunning else { return }
                foodScannerLogger.info("Stopping capture session on camera queue")
                session.stopRunning()
            }
        }
    }

    func capturePhoto(delegate: MealCaptureDelegateProxy) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [photoOutput, session] in
                defer { continuation.resume() }
                guard session.isRunning, !session.isInterrupted else { return }
                let settings = AVCapturePhotoSettings()
                if photoOutput.supportedFlashModes.contains(.auto) {
                    settings.flashMode = .auto
                }
                photoOutput.capturePhoto(with: settings, delegate: delegate)
            }
        }
    }

    func setTorch(enabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                guard let camera, camera.hasTorch else {
                    continuation.resume(returning: false)
                    return
                }
                do {
                    try camera.lockForConfiguration()
                    camera.torchMode = enabled ? .on : .off
                    camera.unlockForConfiguration()
                    continuation.resume(returning: true)
                } catch {
                    foodScannerLogger.error(
                        "Torch configuration failed: \(error.localizedDescription, privacy: .public)"
                    )
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

@MainActor
final class MealCameraViewController: UIViewController {
    private let configuration: JanuaryFoodScannerConfiguration
    private let onImage: @MainActor (UIImage) -> Void
    private let onBarcode: @MainActor (String) -> Void
    private let onCancel: @MainActor () -> Void
    private let cameraRunner = MealCameraSessionRunner()
    private let previewView = MealCameraPreviewView()
    private var captureDelegate: MealCaptureDelegateProxy?
    private var observerTokens: [NSObjectProtocol] = []
    private var cameraHasTorch = false
    private var torchEnabled = false
    private var hasDeliveredBarcode = false
    private var isProcessing = false
    private var isVisible = false
    private var isConfigured = false
    private var isAuthorizingOrConfiguring = false
    private var isObservingSessionNotifications = false

    private let shutterButton = UIButton(type: .custom)
    private let modeControl = UISegmentedControl(items: ["Photo", "Barcode"])
    private let instructionLabel = UILabel()
    private let flashButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)

    private var selectedMode: JanuaryFoodScannerMode {
        modeControl.selectedSegmentIndex == 1 ? .barcode : .photo
    }

    init(
        configuration: JanuaryFoodScannerConfiguration,
        onImage: @escaping @MainActor (UIImage) -> Void,
        onBarcode: @escaping @MainActor (String) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.configuration = configuration
        self.onImage = onImage
        self.onBarcode = onBarcode
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        foodScannerLogger.info("Food scanner view loaded")
        view.backgroundColor = .black
        configurePreview()
        configureOverlay()
        observeApplicationNotifications()
        authorizeAndConfigureCamera()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        Task { await startCameraIfReady() }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        torchEnabled = false
        flashButton.configuration = circleConfiguration(symbol: "bolt.slash.fill")
        Task {
            _ = await cameraRunner.setTorch(enabled: false)
            await cameraRunner.stop()
        }
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }

    func setProcessing(_ processing: Bool) {
        isProcessing = processing
        closeButton.isEnabled = !processing
        flashButton.isEnabled = !processing
        shutterButton.isEnabled = !processing
        modeControl.isEnabled = !processing
        view.accessibilityViewIsModal = processing
    }

    private func authorizeAndConfigureCamera() {
        guard !isConfigured, !isAuthorizingOrConfiguring else { return }
        do {
            try JanuaryFoodScanner.validateHostConfiguration()
        } catch {
            showConfigurationAlert(message: error.localizedDescription)
            return
        }

        isAuthorizingOrConfiguring = true
        Task {
            defer { isAuthorizingOrConfiguring = false }
            switch await MealCameraSessionRunner.authorize() {
            case .authorized:
                foodScannerLogger.info("Camera authorization status: authorized")
                await configureCamera()
            case .denied:
                foodScannerLogger.error("Camera authorization status: denied")
                showCameraAccessAlert(canOpenSettings: true)
            case .restricted:
                foodScannerLogger.error("Camera authorization status: restricted")
                showCameraAccessAlert(canOpenSettings: false)
            }
        }
    }

    private func observeApplicationNotifications() {
        let token = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isVisible, !self.isConfigured else { return }
                self.authorizeAndConfigureCamera()
            }
        }
        observerTokens.append(token)
    }

    private func configureCamera() async {
        let proxy = MealCaptureDelegateProxy(
            onImage: { [weak self] image in
                guard let self, !self.isProcessing else { return }
                self.onImage(image)
            },
            onBarcode: { [weak self] value in
                guard let self,
                      self.selectedMode == .barcode,
                      !self.isProcessing,
                      !self.hasDeliveredBarcode
                else { return }
                self.hasDeliveredBarcode = true
                self.onBarcode(value)
            }
        )
        captureDelegate = proxy

        do {
            let result = try await cameraRunner.configure(
                enabledModes: configuration.enabledModes,
                delegate: proxy
            )
            cameraHasTorch = result.cameraHasTorch
            isConfigured = true
            observeSessionNotifications()
            foodScannerLogger.info(
                "Capture session configured using January iOS lifecycle; camera=\(result.cameraName, privacy: .public), connected=\(result.cameraIsConnected, privacy: .public), inputs=\(result.inputCount, privacy: .public), outputs=\(result.outputCount, privacy: .public)"
            )
            updateModeUI()
            await startCameraIfReady()
        } catch {
            foodScannerLogger.error("Camera configuration failed: \(error.localizedDescription, privacy: .public)")
            showCameraUnavailableAlert()
        }
    }

    private func configurePreview() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewView)
        NSLayoutConstraint.activate([
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        previewView.setSession(cameraRunner.session)
    }

    private func startCameraIfReady() async {
        guard isVisible, isConfigured else {
            foodScannerLogger.debug("Capture start deferred until the scanner is visible and configured")
            return
        }
        await cameraRunner.start()
    }

    private func configureOverlay() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.configuration = circleConfiguration(symbol: "xmark")
        closeButton.tintColor = .white
        closeButton.accessibilityLabel = "Close scanner"
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.configuration = circleConfiguration(symbol: "bolt.slash.fill")
        flashButton.tintColor = .white
        flashButton.accessibilityLabel = "Toggle torch"
        flashButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)

        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionLabel.textColor = .white
        instructionLabel.font = .preferredFont(forTextStyle: .headline)
        instructionLabel.textAlignment = .center
        instructionLabel.numberOfLines = 2

        modeControl.translatesAutoresizingMaskIntoConstraints = false
        modeControl.selectedSegmentTintColor = .white
        modeControl.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        modeControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)

        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 38
        shutterButton.layer.borderWidth = 5
        shutterButton.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        shutterButton.accessibilityLabel = "Take meal photo"
        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)

        [closeButton, flashButton, instructionLabel, modeControl, shutterButton].forEach(view.addSubview)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 52),
            closeButton.heightAnchor.constraint(equalTo: closeButton.widthAnchor),

            flashButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            flashButton.widthAnchor.constraint(equalToConstant: 52),
            flashButton.heightAnchor.constraint(equalTo: flashButton.widthAnchor),

            instructionLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            instructionLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            instructionLabel.bottomAnchor.constraint(equalTo: modeControl.topAnchor, constant: -18),

            modeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            modeControl.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -24),
            modeControl.widthAnchor.constraint(equalToConstant: 220),
            modeControl.heightAnchor.constraint(equalToConstant: 40),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -22),
            shutterButton.widthAnchor.constraint(equalToConstant: 76),
            shutterButton.heightAnchor.constraint(equalTo: shutterButton.widthAnchor),
        ])

        let showsBothModes = configuration.enabledModes.count > 1
        modeControl.isHidden = !showsBothModes
        modeControl.selectedSegmentIndex = configuration.initialMode == .photo ? 0 : 1
        updateModeUI()
    }

    @objc private func cancel() { onCancel() }

    @objc private func modeChanged() { updateModeUI() }

    private func updateModeUI() {
        let isPhoto = selectedMode == .photo
        shutterButton.isHidden = !isPhoto
        flashButton.isHidden = !isPhoto || !cameraHasTorch
        instructionLabel.text = isPhoto
            ? "Fit the whole meal in the frame"
            : "Hold a food barcode in view"
        hasDeliveredBarcode = false
        if !isPhoto { setTorch(enabled: false) }
    }

    @objc private func toggleTorch() {
        guard cameraHasTorch else { return }
        setTorch(enabled: !torchEnabled)
    }

    private func setTorch(enabled: Bool) {
        guard cameraHasTorch else { return }
        Task {
            guard await cameraRunner.setTorch(enabled: enabled) else { return }
            torchEnabled = enabled
            flashButton.configuration = circleConfiguration(symbol: enabled ? "bolt.fill" : "bolt.slash.fill")
        }
    }

    @objc private func capturePhoto() {
        guard !isProcessing, selectedMode == .photo else { return }
        guard let captureDelegate else { return }
        Task { await cameraRunner.capturePhoto(delegate: captureDelegate) }
    }

    private func observeSessionNotifications() {
        guard !isObservingSessionNotifications else { return }
        isObservingSessionNotifications = true
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: cameraRunner.session,
            queue: .main
        ) { notification in
            let rawReason = (notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? NSNumber)?.intValue
            let reason = rawReason.flatMap(AVCaptureSession.InterruptionReason.init(rawValue:))
            foodScannerLogger.error(
                "Capture session interrupted; reason=\(rawReason ?? -1, privacy: .public) (\(String(describing: reason), privacy: .public))"
            )
        })
        observerTokens.append(center.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: cameraRunner.session,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            foodScannerLogger.info("Capture session interruption ended")
            Task { await self.startCameraIfReady() }
        })
        observerTokens.append(center.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: cameraRunner.session,
            queue: .main
        ) { notification in
            let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError
            foodScannerLogger.error(
                "Capture session runtime error: code=\(String(describing: error?.code), privacy: .public), description=\(error?.localizedDescription ?? "unknown", privacy: .public)"
            )
        })
    }

    private func circleConfiguration(symbol: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: symbol)
        configuration.baseBackgroundColor = UIColor.black.withAlphaComponent(0.55)
        configuration.cornerStyle = .capsule
        return configuration
    }

    private func showCameraAccessAlert(canOpenSettings: Bool) {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "This app"
        let message = canOpenSettings
            ? "Allow camera access for \(appName) in Settings to photograph a meal or scan a barcode."
            : "Camera access is restricted on this device."
        let alert = UIAlertController(title: "Camera access is off", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.onCancel() })
        if canOpenSettings {
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            })
        }
        present(alert, animated: true)
    }

    private func showConfigurationAlert(message: String) {
        let alert = UIAlertController(title: "Camera setup required", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .default) { [weak self] _ in self?.onCancel() })
        present(alert, animated: true)
    }

    private func showCameraUnavailableAlert() {
        let alert = UIAlertController(
            title: "Camera unavailable",
            message: "The camera could not be started. Close other apps using the camera and try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Close", style: .default) { [weak self] _ in self?.onCancel() })
        present(alert, animated: true)
    }
}
