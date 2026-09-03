import January
import PhotosUI
import SwiftUI
import UIKit

struct ScanView: View {
    let client: JanuaryClient
    let settingsAction: () -> Void

    @EnvironmentObject private var userSession: UserSession
    @State private var imageInput = ""
    @State private var previewImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var presentedResult: ScanResultPresentation?
    @State private var pendingScannerResult: ScanResultPresentation?
    @State private var error: Error?
    @State private var isLoading = false
    @State private var isShowingCamera = false
    @State private var isShowingURL = false
    @State private var pendingBarcodeFood: FoodSearchItem?
    @State private var presentedBarcodeFood: BarcodeFoodPresentation?

    private var endUserID: String { userSession.endUserID }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    imageInputContent
                }
                .padding(.horizontal, AppSpacing.screen)
                .padding(.vertical, 16)
            }
            .appBackground()
            .appNavigationBar("Scan a meal", style: .leading) {
                EmptyView()
            } trailing: {
                AppNavigationButton(.settings, action: settingsAction)
            }
            .fullScreenCover(isPresented: $isShowingCamera, onDismiss: presentPendingScannerResult) {
                JanuaryFoodScannerView(
                    client: client,
                    endUserID: AppFormatting.endUserID(endUserID),
                    onResult: { scannerResult in
                        isShowingCamera = false
                        switch scannerResult {
                        case .photo(let image, let analysis):
                            previewImage = image.image
                            imageInput = image.dataURI
                            pendingScannerResult = ScanResultPresentation(result: analysis, previewImage: image.image)
                            error = nil
                        case .barcode(_, let food):
                            pendingBarcodeFood = food
                        }
                    },
                    onCancel: { isShowingCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(item: $presentedResult) { presentation in
                ScanResultSheet(
                    client: client,
                    presentation: presentation,
                    endUserID: AppFormatting.endUserID(endUserID),
                    onScanAnother: reset
                )
            }
            .sheet(isPresented: $isShowingURL) {
                ImageURLSheet { url in
                    imageInput = url.absoluteString
                    previewImage = nil
                    isShowingURL = false
                }
            }
            .sheet(item: $presentedBarcodeFood) { presentation in
                NavigationStack {
                    FoodDetailView(
                        client: client,
                        food: presentation.food,
                        endUserID: AppFormatting.endUserID(endUserID)
                    )
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        await MainActor.run { setLocalImage(image) }
                    }
                }
            }
        }
    }

    private var imageInputContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            if imageInput.isEmpty {
                ScanPhotoInstructions()

                PrimaryButton(title: "Take photo", systemImage: "camera") {
                    presentCamera()
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose from library", systemImage: "photo")
                }
                .buttonStyle(SecondaryButtonStyle())

                SectionLabel("Other ways")
                LazyVGrid(columns: actionColumns, spacing: 10) {
                    Button("Sample meal", systemImage: "fork.knife") { useSampleMeal() }
                        .buttonStyle(OutlinedButtonStyle())
                    Button("Image URL", systemImage: "link") { isShowingURL = true }
                        .buttonStyle(OutlinedButtonStyle())
                }
            } else {
                ScanImagePreview { imageInputPreview }

                LazyVGrid(columns: actionColumns, spacing: 10) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Change photo", systemImage: "photo")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button("Remove", systemImage: "trash") {
                        reset()
                    }
                    .buttonStyle(OutlinedButtonStyle())
                }

                PrimaryButton(
                    title: "Analyze meal",
                    isLoading: isLoading
                ) {
                    Task { await analyze() }
                }
            }

            if isLoading {
                Text("Complex meals can take a little longer. You can leave this screen while the request completes.")
                    .font(.subheadline).foregroundStyle(AppPalette.muted)
            }
            if let error { ErrorNotice(error: error) { Task { await analyze() } } }
        }
    }

    @ViewBuilder
    private var imageInputPreview: some View {
        if let previewImage {
            Image(uiImage: previewImage)
                .resizable()
                .scaledToFill()
        } else if let url = URL(string: imageInput), !imageInput.isEmpty {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                LoadingSpinner(color: AppPalette.green)
            }
        }
    }

    private var actionColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]
    }

    @MainActor
    private func analyze() async {
        guard !imageInput.isEmpty else { return }
        isLoading = true; error = nil
        do {
            let analysis = try await client.foodAnalysis.analyzePhoto(
                .init(image: imageInput, endUserID: AppFormatting.endUserID(endUserID))
            )
            presentedResult = ScanResultPresentation(result: analysis, previewImage: previewImage)
        } catch { self.error = error }
        isLoading = false
    }

    private func setLocalImage(_ image: UIImage) {
        guard let originalData = image.jpegData(compressionQuality: 1),
              let compressedData = try? PhotoScanImage.jpegData(from: originalData),
              let compressedImage = UIImage(data: compressedData)
        else { return }
        previewImage = compressedImage
        imageInput = "data:image/jpeg;base64,\(compressedData.base64EncodedString())"
        presentedResult = nil; pendingScannerResult = nil; error = nil
    }

    private func useSampleMeal() {
        guard let image = UIImage(named: "burger-and-fries") else {
            error = AppLocalError("The bundled sample meal couldn’t be loaded.")
            return
        }
        setLocalImage(image)
    }

    private func reset() {
        imageInput = ""; previewImage = nil; selectedPhoto = nil
        presentedResult = nil; pendingScannerResult = nil; error = nil
    }

    private func presentCamera() {
        pendingBarcodeFood = nil
        pendingScannerResult = nil
        presentedBarcodeFood = nil
        isShowingCamera = true
    }

    private func presentPendingScannerResult() {
        if let food = pendingBarcodeFood {
            pendingBarcodeFood = nil
            presentedBarcodeFood = BarcodeFoodPresentation(food: food)
        } else if let result = pendingScannerResult {
            pendingScannerResult = nil
            presentedResult = result
        }
    }
}

private struct ScanResultPresentation: Identifiable {
    let id = UUID()
    let result: FoodScan
    let previewImage: UIImage?
}

private struct ScanResultSheet: View {
    let client: JanuaryClient
    let presentation: ScanResultPresentation
    let endUserID: PartnerUserID?
    let onScanAnother: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var result: FoodScan
    @State private var isShowingCorrection = false

    init(
        client: JanuaryClient,
        presentation: ScanResultPresentation,
        endUserID: PartnerUserID?,
        onScanAnother: @escaping () -> Void
    ) {
        self.client = client
        self.presentation = presentation
        self.endUserID = endUserID
        self.onScanAnother = onScanAnother
        _result = State(initialValue: presentation.result)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    VStack(alignment: .leading, spacing: 18) {
                        ScanResultContent(result: result, previewImage: presentation.previewImage)

                        PrimaryButton(title: "Correct result") {
                            isShowingCorrection = true
                        }

                        Button("Scan another meal") {
                            onScanAnother()
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 32)
            }
            .appBackground()
            .appNavigationBar("Meal analysis") {
                AppNavigationButton(.close, title: "Close result") { dismiss() }
            } trailing: {
                EmptyView()
            }
            .sheet(isPresented: $isShowingCorrection) {
                CorrectScanView(client: client, scan: result, endUserID: endUserID) { corrected in
                    result = corrected
                    isShowingCorrection = false
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

private struct BarcodeFoodPresentation: Identifiable {
    let id = UUID()
    let food: FoodSearchItem
}

private struct ScanResultContent: View {
    let result: FoodScan
    let previewImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let previewImage {
                RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous)
                    .fill(AppPalette.control)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        Image(uiImage: previewImage)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous))
            }
            Text(result.mealName ?? "Meal analysis")
                .font(.system(.largeTitle, design: .serif, weight: .bold))

            let nutrients = result.totalNutrients
            Group {
                MacroGrid(
                    calories: nutrients.calories?.value,
                    protein: nutrients.protein?.value,
                    carbohydrates: nutrients.carbohydrates?.value,
                    fat: nutrients.totalFat?.value
                ).appCard()
                let rows = completeNutrientRows(nutrients)
                if !rows.isEmpty { NutritionList(rows: rows).appCard() }
            }

            if !result.detections.isEmpty {
                Text("Detected foods").font(.system(.title2, design: .serif, weight: .semibold))
                ForEach(Array(result.detections.enumerated()), id: \.offset) { _, detection in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(detection.food.name ?? "Unnamed food").font(.headline)
                            Spacer()
                            if let confidence = detection.confidenceScore {
                                Text("\(confidence.rawValue.capitalized) confidence")
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(confidenceColor(confidence).opacity(0.13), in: Capsule())
                                    .foregroundStyle(confidenceColor(confidence))
                            }
                        }
                        if let brand = detection.food.brandName { Text(brand).foregroundStyle(AppPalette.muted) }
                        MacroGrid(
                            calories: detection.food.nutrients.calories?.value,
                            protein: detection.food.nutrients.protein?.value,
                            carbohydrates: detection.food.nutrients.carbohydrates?.value,
                            fat: detection.food.nutrients.totalFat?.value
                        )
                    }.appCard()
                }
            }

            if let impact = result.glucoseImpact, !impact.prediction.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Estimated glucose response").font(.system(.title2, design: .serif, weight: .semibold))
                    Text(impact.impactScore.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.headline).foregroundStyle(AppPalette.rust)
                    PredictionChart(
                        points: impact.prediction.map { .init(minutes: $0.minutes, value: $0.value) },
                        lowerBound: nil,
                        upperBound: nil,
                        lineColor: AppPalette.rust
                    )
                }
            }
        }
    }

    private func confidenceColor(_ score: ConfidenceScore) -> Color {
        switch score { case .high: return AppPalette.green; case .medium: return AppPalette.rust; case .low: return AppPalette.muted }
    }
}

private struct CorrectScanView: View {
    let client: JanuaryClient
    let scan: FoodScan
    let endUserID: PartnerUserID?
    let onSuccess: (FoodScan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mealName: String
    @State private var correction = ""
    @State private var isLoading = false
    @State private var error: Error?

    init(client: JanuaryClient, scan: FoodScan, endUserID: PartnerUserID?, onSuccess: @escaping (FoodScan) -> Void) {
        self.client = client; self.scan = scan; self.endUserID = endUserID; self.onSuccess = onSuccess
        _mealName = State(initialValue: scan.mealName ?? "Meal")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    VStack(alignment: .leading, spacing: AppSpacing.section) {
                        SectionLabel("Meal")
                        TextField("Meal name", text: $mealName)
                            .font(AppTypography.body)
                            .padding(.horizontal, AppSpacing.controlHorizontal)
                            .frame(minHeight: 56)
                            .background(
                                AppPalette.control,
                                in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                            )

                        SectionLabel("Current detections")
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(scan.detections.enumerated()), id: \.offset) { index, detection in
                                Text(detection.food.name ?? "Unnamed food")
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppPalette.ink)
                                    .padding(.vertical, AppSpacing.rowVertical)
                                if index < scan.detections.count - 1 { Divider() }
                            }
                        }
                        .appCard()

                        SectionLabel("What should change?")
                        ZStack(alignment: .topLeading) {
                            if correction.isEmpty {
                                Text("Describe the correction")
                                    .font(AppTypography.body)
                                    .foregroundStyle(AppPalette.subdued)
                                    .padding(.horizontal, 17)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $correction)
                                .font(AppTypography.body)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .frame(minHeight: 150)
                                .background(Color.clear)
                        }
                        .background(
                            AppPalette.surface,
                            in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                .stroke(AppPalette.border, lineWidth: 1)
                        }

                        Text("For example: The oatmeal was steel-cut, about 2 cups, and there was no honey.")
                            .font(.footnote)
                            .foregroundStyle(AppPalette.muted)

                        if let error {
                            ErrorNotice(error: error) { Task { await submit() } }
                        }

                    PrimaryButton(
                        title: "Submit correction",
                        isLoading: isLoading,
                        isDisabled: correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        Task { await submit() }
                        }
                    }
                }
                .padding(.vertical, AppSpacing.sheetTop)
            }
            .appBackground()
            .appNavigationBar("Correct result") {
                AppNavigationButton(.close, title: "Close correction") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    @MainActor private func submit() async {
        guard !scan.detections.isEmpty else {
            error = AppLocalError("There are no detections available to correct."); return
        }
        isLoading = true; error = nil
        do {
            let corrected = try await client.foodAnalysis.correct(.init(mealName: mealName, detections: scan.detections, userInput: correction, endUserID: endUserID))
            onSuccess(corrected)
        } catch { self.error = error }
        isLoading = false
    }
}

private struct ImageURLSheet: View {
    let onSelect: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Public image", systemImage: "link")
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppPalette.green)
                            Text("Paste a direct HTTPS link to a meal photo.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppPalette.body)
                        }
                        .appCard()

                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Image address")
                            TextField("https://example.com/meal.jpg", text: $text)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(AppTypography.body)
                                .padding(.horizontal, AppSpacing.controlHorizontal)
                                .frame(minHeight: 56)
                                .background(
                                    AppPalette.control,
                                    in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                )
                            Text("The server must be able to download the image without signing in.")
                                .font(.footnote)
                                .foregroundStyle(AppPalette.muted)
                        }

                        PrimaryButton(
                            title: "Use image URL",
                            systemImage: "arrow.down.circle",
                            isDisabled: validURL == nil
                        ) {
                            if let url = validURL { onSelect(url) }
                        }
                    }
                }
                .padding(.vertical, AppSpacing.sheetTop)
            }
            .appBackground()
            .appNavigationBar("Use image URL") {
                AppNavigationButton(.close, title: "Close image URL entry") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var validURL: URL? {
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
}

struct AppLocalError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

func completeNutrientRows(_ value: CompleteScanNutritionFacts) -> [NutrientRow] {
    [
        value.netCarbohydrates.map { .init(name: "Net carbohydrates", value: $0.value, unit: $0.unit) },
        value.saturatedFat.map { .init(name: "Saturated fat", value: $0.value, unit: $0.unit) },
        value.fiber.map { .init(name: "Fiber", value: $0.value, unit: $0.unit) },
        value.totalSugars.map { .init(name: "Total sugars", value: $0.value, unit: $0.unit) },
        value.addedSugars.map { .init(name: "Added sugars", value: $0.value, unit: $0.unit) },
        value.sodium.map { .init(name: "Sodium", value: $0.value, unit: $0.unit) },
    ].compactMap { $0 }
}
