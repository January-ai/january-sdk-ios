#if os(iOS)
import Foundation
import OSLog
import SwiftUI
import UIKit

private let mealScannerWorkflowLogger = Logger(
    subsystem: "ai.january.partner.sdk",
    category: "MealScannerWorkflow"
)

/// A capture mode available in ``JanuaryMealScannerView``.
public enum JanuaryMealScannerMode: Hashable, Sendable {
    case photo
    case barcode
}

/// Configuration for January's ready-to-use meal scanner.
public struct JanuaryMealScannerConfiguration: Hashable, Sendable {
    public var enabledModes: Set<JanuaryMealScannerMode>
    public var initialMode: JanuaryMealScannerMode
    public var maximumImageDimension: Int
    public var compressionQuality: Double

    public init(
        enabledModes: Set<JanuaryMealScannerMode> = [.photo, .barcode],
        initialMode: JanuaryMealScannerMode = .photo,
        maximumImageDimension: Int = PhotoScanImage.defaultMaxDimension,
        compressionQuality: Double = PhotoScanImage.defaultCompressionQuality
    ) {
        let modes = enabledModes.isEmpty ? Set([JanuaryMealScannerMode.photo]) : enabledModes
        self.enabledModes = modes
        self.initialMode = modes.contains(initialMode)
            ? initialMode
            : (modes.contains(.photo) ? .photo : .barcode)
        self.maximumImageDimension = max(1, maximumImageDimension)
        self.compressionQuality = min(max(compressionQuality, 0), 1)
    }
}

/// The exact, upload-ready meal image produced by the scanner.
public struct JanuaryProcessedMealImage {
    public let image: UIImage
    public let jpegData: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    public var dataURI: String {
        "data:image/jpeg;base64,\(jpegData.base64EncodedString())"
    }

    fileprivate init(image: UIImage, jpegData: Data) {
        self.image = image
        self.jpegData = jpegData
        self.pixelWidth = image.cgImage?.width ?? Int(image.size.width * image.scale)
        self.pixelHeight = image.cgImage?.height ?? Int(image.size.height * image.scale)
    }
}

/// A completed camera or barcode workflow.
public enum JanuaryMealScannerResult {
    /// The analyzed meal and the processed image that was sent to January.
    case meal(image: JanuaryProcessedMealImage, analysis: FoodScan)
    /// The detected barcode and its complete food record.
    case barcode(value: String, food: FoodSearchItem)
}

public enum JanuaryMealScannerConfigurationError: Error, LocalizedError, Sendable {
    case missingCameraUsageDescription

    public var errorDescription: String? {
        switch self {
        case .missingCameraUsageDescription:
            "Add NSCameraUsageDescription to the host app's Info.plist before presenting the January meal scanner."
        }
    }
}

/// Entry points and configuration validation for January's meal scanner.
public enum JanuaryMealScanner {
    /// Validates the only host-app configuration required by the camera flow.
    public static func validateHostConfiguration(in bundle: Bundle = .main) throws {
        let description = bundle.object(forInfoDictionaryKey: "NSCameraUsageDescription") as? String
        guard let description, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw JanuaryMealScannerConfigurationError.missingCameraUsageDescription
        }
    }

    /// Creates the UIKit presentation of the same scanner used by SwiftUI clients.
    @MainActor
    public static func makeViewController(
        client: JanuaryClient,
        endUserID: PartnerUserID? = nil,
        configuration: JanuaryMealScannerConfiguration = .init(),
        onResult: @escaping @MainActor (JanuaryMealScannerResult) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) -> UIViewController {
        let controller = UIHostingController(
            rootView: JanuaryMealScannerView(
                client: client,
                endUserID: endUserID,
                configuration: configuration,
                onResult: onResult,
                onCancel: onCancel
            )
        )
        controller.modalPresentationStyle = .fullScreen
        return controller
    }
}

/// A full-screen, native camera that captures meal photos and scans food barcodes.
@MainActor
public struct JanuaryMealScannerView: View {
    private let client: JanuaryClient
    private let endUserID: PartnerUserID?
    private let configuration: JanuaryMealScannerConfiguration
    private let onResult: @MainActor (JanuaryMealScannerResult) -> Void
    private let onCancel: @MainActor () -> Void

    @State private var processingLabel: String?
    @State private var failure: ScannerFailure?
    @State private var cameraIdentity = UUID()

    public init(
        client: JanuaryClient,
        endUserID: PartnerUserID? = nil,
        configuration: JanuaryMealScannerConfiguration = .init(),
        onResult: @escaping @MainActor (JanuaryMealScannerResult) -> Void,
        onCancel: @escaping @MainActor () -> Void
    ) {
        self.client = client
        self.endUserID = endUserID
        self.configuration = configuration
        self.onResult = onResult
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            MealCameraRepresentable(
                configuration: configuration,
                isProcessing: processingLabel != nil,
                onImage: { image in
                    Task { await analyze(image) }
                },
                onBarcode: { barcode in
                    Task { await lookUp(barcode) }
                },
                onCancel: onCancel
            )
            .id(cameraIdentity)
            .ignoresSafeArea()

            if let processingLabel {
                Color.black.opacity(0.42).ignoresSafeArea()
                VStack(spacing: 14) {
                    ScannerLoadingSpinner()
                    Text(processingLabel)
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 22)
                .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
        .preferredColorScheme(.dark)
        .alert(item: $failure) { failure in
            Alert(
                title: Text(failure.title),
                message: Text(failure.message),
                primaryButton: .default(Text("Try Again")) {
                    processingLabel = nil
                    cameraIdentity = UUID()
                },
                secondaryButton: .cancel(Text("Close"), action: onCancel)
            )
        }
    }

    private func analyze(_ capturedImage: UIImage) async {
        guard processingLabel == nil else { return }
        processingLabel = "Analyzing meal…"
        do {
            let image = try JanuaryProcessedMealImage.process(
                capturedImage,
                maximumDimension: configuration.maximumImageDimension,
                compressionQuality: configuration.compressionQuality
            )
            let analysis = try await client.photoScanning.scan(
                .init(image: image.dataURI, endUserID: endUserID)
            )
            mealScannerWorkflowLogger.info(
                "Meal scan response received; meal=\(analysis.mealName ?? "unnamed", privacy: .public), detections=\(analysis.detections.count), hasNutrition=\(analysis.totalNutrients != nil)"
            )
            processingLabel = nil
            onResult(.meal(image: image, analysis: analysis))
        } catch {
            mealScannerWorkflowLogger.error(
                "Meal scan request failed; error=\(String(describing: error), privacy: .public)"
            )
            processingLabel = nil
            failure = .init(title: "Meal scan failed", error: error)
        }
    }

    private func lookUp(_ barcode: String) async {
        guard processingLabel == nil else { return }
        processingLabel = "Looking up barcode…"
        do {
            let results = try await client.foods.lookupByBarcode(
                .init(upc: barcode, endUserID: endUserID)
            )
            mealScannerWorkflowLogger.info(
                "Barcode lookup response received; barcode=\(barcode, privacy: .public), items=\(results.items.count)"
            )
            guard let match = results.items.first else {
                throw ScannerLookupError.noBarcodeMatch
            }
            mealScannerWorkflowLogger.info(
                "Barcode match selected; foodID=\(match.id.rawValue), name=\(match.name, privacy: .public)"
            )
            let food = try await client.foods.getFood(
                .init(foodID: match.id, endUserID: endUserID)
            )
            mealScannerWorkflowLogger.info(
                "Full food response received; foodID=\(food.id.rawValue), name=\(food.name, privacy: .public), servings=\(food.servings.count)"
            )
            processingLabel = nil
            onResult(.barcode(value: barcode, food: food))
        } catch {
            mealScannerWorkflowLogger.error(
                "Barcode workflow failed; barcode=\(barcode, privacy: .public), error=\(String(describing: error), privacy: .public)"
            )
            processingLabel = nil
            failure = .init(title: "Barcode lookup failed", error: error)
        }
    }
}

private struct ScannerFailure: Identifiable {
    let id = UUID()
    let title: String
    let message: String

    init(title: String, error: Error) {
        self.title = title
        self.message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private enum ScannerLookupError: Error, LocalizedError {
    case noBarcodeMatch

    var errorDescription: String? {
        "January couldn't find a food matching this barcode."
    }
}

private extension JanuaryProcessedMealImage {
    static func process(
        _ source: UIImage,
        maximumDimension: Int,
        compressionQuality: Double
    ) throws -> JanuaryProcessedMealImage {
        guard source.size.width > 0, source.size.height > 0 else {
            throw PhotoScanImageError.invalidImage
        }

        guard let sourceData = source.jpegData(compressionQuality: 1) else {
            throw PhotoScanImageError.encodingFailed
        }
        let data = try PhotoScanImage.jpegData(
            from: sourceData,
            maxDimension: maximumDimension,
            compressionQuality: compressionQuality
        )
        guard let image = UIImage(data: data) else {
            throw PhotoScanImageError.invalidImage
        }
        return JanuaryProcessedMealImage(image: image, jpegData: data)
    }
}
#endif
