import JanuaryPartnerSDK
import PhotosUI
import SwiftUI
import UIKit

struct ScanView: View {
    let client: JanuaryPartnerClient
    let settingsAction: () -> Void

    @AppStorage("demo.endUserID") private var endUserID = ""
    @State private var imageInput = ""
    @State private var previewImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var result: FoodScan?
    @State private var error: Error?
    @State private var isLoading = false
    @State private var isShowingCamera = false
    @State private var isShowingURL = false
    @State private var isShowingCorrection = false

    var body: some View {
        NavigationStack {
            ScrollView {
                DemoScreenShell {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Scan a meal")
                            .font(DemoTypography.screenTitle)
                            .foregroundStyle(DemoPalette.ink)

                        if let result {
                            ScanResultContent(result: result, previewImage: previewImage)
                            Button("Correct result") { isShowingCorrection = true }
                                .buttonStyle(DemoPrimaryButtonStyle())
                            Button("Scan another meal") { reset() }
                                .buttonStyle(DemoSecondaryButtonStyle())
                        } else {
                            imageInputContent
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .demoBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    setLocalImage(image)
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isShowingURL) {
                ImageURLSheet { url in
                    imageInput = url.absoluteString
                    previewImage = nil
                    isShowingURL = false
                }
            }
            .sheet(isPresented: $isShowingCorrection) {
                if let result {
                    CorrectScanView(client: client, scan: result, endUserID: DemoFormatting.endUserID(endUserID)) { corrected in
                        self.result = corrected
                        isShowingCorrection = false
                    }
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
            DemoFillWidth {
                ZStack {
                    if let previewImage {
                        Image(uiImage: previewImage).resizable().scaledToFill()
                    } else if let url = URL(string: imageInput), !imageInput.isEmpty {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { ProgressView() }
                    } else {
                        ZStack {
                            ScanPlaceholderPattern()
                            VStack(spacing: 12) {
                                Image(systemName: "camera")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(DemoPalette.muted)
                                Text("Add a clear photo of the whole meal")
                                    .font(DemoTypography.cardTitle)
                                    .multilineTextAlignment(.center)
                                Text("January identifies the foods, servings, and nutrition — then estimates your response.")
                                    .font(.system(size: 16))
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(DemoPalette.body)
                            }
                            .padding(24)
                        }
                    }
                }
            }
            .frame(height: 340)
            .clipped()
            .background(DemoPalette.control)
            .clipShape(RoundedRectangle(cornerRadius: DemoRadius.feature, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DemoRadius.feature, style: .continuous)
                    .stroke(DemoPalette.border, lineWidth: 1.5)
            }

            DemoEqualColumns(spacing: 10) {
                Button("Take photo", systemImage: "camera") { isShowingCamera = true }
                    .buttonStyle(DemoPrimaryButtonStyle())
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose photo", systemImage: "photo")
                }
                .buttonStyle(DemoSecondaryButtonStyle())
            }

            DemoEqualColumns(spacing: 10) {
                Button("Use sample meal", systemImage: "fork.knife") { useSampleMeal() }
                    .buttonStyle(DemoOutlinedButtonStyle())
                Button("Use image URL", systemImage: "link") { isShowingURL = true }
                    .buttonStyle(DemoOutlinedButtonStyle())
            }

            if imageInput.isEmpty {
                DemoFillWidth {
                    HStack {
                        Spacer(minLength: 0)
                        Text("Analyze appears once a photo is added.")
                            .font(.system(size: 14))
                            .foregroundStyle(DemoPalette.muted)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                    }
                }
            }

            if !imageInput.isEmpty {
                Button { Task { await analyze() } } label: {
                    if isLoading {
                        HStack { ProgressView().tint(DemoPalette.paper); Text("Analyzing this meal…") }
                    } else { Text("Analyze meal") }
                }
                .buttonStyle(DemoPrimaryButtonStyle())
                .disabled(isLoading)
            }

            if isLoading {
                Text("Complex meals can take a little longer. You can leave this screen while the request completes.")
                    .font(.subheadline).foregroundStyle(DemoPalette.muted)
            }
            if let error { DemoErrorNotice(error: error) { Task { await analyze() } } }
        }
    }

    @MainActor
    private func analyze() async {
        guard !imageInput.isEmpty else { return }
        isLoading = true; error = nil
        do {
            result = try await client.photoScanning.scan(.init(image: imageInput, endUserID: DemoFormatting.endUserID(endUserID)))
        } catch { self.error = error }
        isLoading = false
    }

    private func setLocalImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return }
        previewImage = image
        imageInput = "data:image/jpeg;base64,\(data.base64EncodedString())"
        result = nil; error = nil
    }

    private func useSampleMeal() {
        guard let image = UIImage(named: "burger-and-fries") else {
            error = DemoLocalError("The bundled sample meal couldn’t be loaded.")
            return
        }
        setLocalImage(image)
    }

    private func reset() {
        imageInput = ""; previewImage = nil; selectedPhoto = nil; result = nil; error = nil
    }
}

private struct ScanPlaceholderPattern: View {
    var body: some View {
        Canvas { context, size in
            let stripe = DemoPalette.controlStrong.opacity(0.48)
            for offset in stride(from: -size.height, through: size.width, by: 22) {
                var path = Path()
                path.move(to: CGPoint(x: offset, y: size.height))
                path.addLine(to: CGPoint(x: offset + size.height, y: 0))
                context.stroke(path, with: .color(stripe), lineWidth: 9)
            }
        }
        .background(DemoPalette.control)
        .accessibilityHidden(true)
    }
}

private struct ScanResultContent: View {
    let result: FoodScan
    let previewImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let previewImage {
                DemoFillWidth {
                    Image(uiImage: previewImage).resizable().scaledToFill()
                }
                    .frame(height: 210)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            Text(result.mealName ?? "Meal analysis")
                .font(.system(.largeTitle, design: .serif, weight: .bold))

            if let nutrients = result.totalNutrients {
                DemoMacroStrip(
                    calories: nutrients.calories?.value,
                    protein: nutrients.protein?.value,
                    carbohydrates: nutrients.carbohydrates?.value,
                    fat: nutrients.totalFat?.value
                ).demoCard()
                let rows = completeNutrientRows(nutrients)
                if !rows.isEmpty { DemoNutritionList(rows: rows).demoCard() }
            }

            if !result.detections.isEmpty {
                Text("Detected foods").font(.system(.title2, design: .serif, weight: .semibold))
                ForEach(Array(result.detections.enumerated()), id: \.offset) { _, detection in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(detection.food.name).font(.headline)
                            Spacer()
                            if let confidence = detection.confidenceScore {
                                Text(confidence.rawValue.capitalized)
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 10).padding(.vertical, 5)
                                    .background(confidenceColor(confidence).opacity(0.13), in: Capsule())
                                    .foregroundStyle(confidenceColor(confidence))
                            }
                        }
                        if let brand = detection.food.brandName { Text(brand).foregroundStyle(DemoPalette.muted) }
                        DemoMacroStrip(
                            calories: detection.food.nutrients.calories?.value,
                            protein: detection.food.nutrients.protein?.value,
                            carbohydrates: detection.food.nutrients.carbohydrates?.value,
                            fat: detection.food.nutrients.totalFat?.value
                        )
                    }.demoCard()
                }
            }

            if let impact = result.glucoseImpact, !impact.prediction.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Estimated glucose response").font(.system(.title2, design: .serif, weight: .semibold))
                    Text(impact.impactScore.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.headline).foregroundStyle(DemoPalette.rust)
                    DemoPredictionChart(
                        points: impact.prediction.map { .init(minutes: $0.minutes, value: $0.value) },
                        lowerBound: nil,
                        upperBound: nil,
                        lineColor: DemoPalette.rust
                    )
                }
            }
        }
    }

    private func confidenceColor(_ score: ConfidenceScore) -> Color {
        switch score { case .high: return DemoPalette.green; case .medium: return DemoPalette.rust; case .low: return DemoPalette.muted }
    }
}

private struct CorrectScanView: View {
    let client: JanuaryPartnerClient
    let scan: FoodScan
    let endUserID: PartnerUserID?
    let onSuccess: (FoodScan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mealName: String
    @State private var correction = ""
    @State private var isLoading = false
    @State private var error: Error?

    init(client: JanuaryPartnerClient, scan: FoodScan, endUserID: PartnerUserID?, onSuccess: @escaping (FoodScan) -> Void) {
        self.client = client; self.scan = scan; self.endUserID = endUserID; self.onSuccess = onSuccess
        _mealName = State(initialValue: scan.mealName ?? "Meal")
    }

    var body: some View {
        NavigationStack {
            DemoScreenShell {
                Form {
                Section("Meal") { TextField("Meal name", text: $mealName) }
                Section("Current detections") {
                    ForEach(Array(scan.detections.enumerated()), id: \.offset) { _, detection in Text(detection.food.name) }
                }
                Section {
                    TextField("What should change?", text: $correction, axis: .vertical).lineLimit(4...8)
                } footer: {
                    Text("For example: The oatmeal was steel-cut, about 2 cups, and there was no honey.")
                }
                if let error { Section { DemoErrorNotice(error: error) { Task { await submit() } } } }
                Section {
                    Button { Task { await submit() } } label: {
                        if isLoading { ProgressView() } else { Text("Submit correction") }
                    }.disabled(correction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
                }
            }
            .navigationTitle("Correct result").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.large])
    }

    @MainActor private func submit() async {
        guard !scan.detections.isEmpty else {
            error = DemoLocalError("There are no detections available to correct."); return
        }
        isLoading = true; error = nil
        do {
            let corrected = try await client.photoScanning.correct(.init(mealName: mealName, detections: scan.detections, userInput: correction, endUserID: endUserID))
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
            DemoScreenShell {
                Form {
                Section {
                    TextField("https://…", text: $text).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                } header: {
                    Text("Public image URL")
                } footer: {
                    Text("The server must be able to download the image without signing in.")
                }
                }
            }
            .navigationTitle("Use image URL").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use URL") { if let url = validURL { onSelect(url) } }.disabled(validURL == nil)
                }
            }
        }.presentationDetents([.medium])
    }

    private var validURL: URL? {
        guard let url = URL(string: text), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .camera; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage) -> Void
        init(onImage: @escaping (UIImage) -> Void) { self.onImage = onImage }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { onImage(image) }
        }
    }
}

struct DemoLocalError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

func completeNutrientRows(_ value: CompleteScanNutritionFacts) -> [DemoNutrientRow] {
    [
        value.netCarbohydrates.map { .init(name: "Net carbohydrates", value: $0.value, unit: $0.unit) },
        value.saturatedFat.map { .init(name: "Saturated fat", value: $0.value, unit: $0.unit) },
        value.fiber.map { .init(name: "Fiber", value: $0.value, unit: $0.unit) },
        value.totalSugars.map { .init(name: "Total sugars", value: $0.value, unit: $0.unit) },
        value.addedSugars.map { .init(name: "Added sugars", value: $0.value, unit: $0.unit) },
        value.sodium.map { .init(name: "Sodium", value: $0.value, unit: $0.unit) },
    ].compactMap { $0 }
}
