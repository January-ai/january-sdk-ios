import January
import SwiftUI

struct GlucoseView: View {
    let client: JanuaryClient
    let settingsAction: () -> Void

    @EnvironmentObject private var userSession: UserSession
    @State private var age = 42.0
    @State private var sex = Sex.female
    @State private var height = 66.0
    @State private var weight = 150.0
    @State private var conditions: Set<MedicalCondition> = []
    @State private var foods: [SelectedFood] = []
    @State private var startTime = Date.now
    @State private var isShowingFoodPicker = false
    @State private var prediction: GlucosePrediction?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            Group {
                if let prediction {
                    GlucoseResultView(prediction: prediction, foods: foods) {
                        self.prediction = nil
                    } startOver: {
                        self.prediction = nil; self.foods = []
                    }
                } else {
                    predictionForm
                }
            }
            .sheet(isPresented: $isShowingFoodPicker) {
                FoodPickerView(client: client, endUserID: userSession.partnerUserID) { selected in
                    foods.append(selected); isShowingFoodPicker = false
                }
            }
        }
    }

    private var predictionForm: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 24) {
                    WorkflowGuideCard(
                        title: "Estimate this meal’s response",
                        message: "Glucose prediction is a simulation. Your profile shapes the estimate, and the foods and servings define the meal. It does not create a food log.",
                        steps: [
                            "Review the prediction profile",
                            "Add every food in the meal to simulate",
                            "Estimate the glucose response curve"
                        ],
                        symbol: "waveform.path.ecg"
                    )

                    formSection(
                        "Prediction profile",
                        detail: "Age, sex, body measurements, and health conditions influence the estimated response."
                    ) {
                        VStack(spacing: 0) {
                            measurementRow("Age", value: $age, unit: "years")
                            Divider()

                            HStack(spacing: 16) {
                                Text("Sex")
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppPalette.ink)
                                Spacer(minLength: 12)
                                Picker("Sex", selection: $sex) {
                                    Text("Female").tag(Sex.female)
                                    Text("Male").tag(Sex.male)
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                            }
                            .padding(.vertical, 14)

                            Divider()
                            HeightInput(heightInches: $height)
                            Divider()
                            WeightInput(weightPounds: $weight)
                            Divider()
                            NavigationLink {
                                ConditionSelectionView(selection: $conditions)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("Health conditions")
                                        .foregroundStyle(AppPalette.ink)
                                    Spacer(minLength: 12)
                                    Text(conditionSummary)
                                        .foregroundStyle(AppPalette.muted)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                        }
                    }

                    formSection(
                        "Meal to simulate",
                        detail: "Add one or more foods here. This meal is used only for the prediction and is not saved to Food Logs."
                    ) {
                        VStack(spacing: 0) {
                            DatePicker("Start time", selection: $startTime)
                                .padding(.vertical, 8)

                            ForEach($foods) { $item in
                                Divider()
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.food.name ?? "Unnamed food")
                                            .font(AppTypography.bodyStrong)
                                            .foregroundStyle(AppPalette.ink)
                                        Picker("Serving", selection: $item.serving) {
                                            ForEach(item.food.servings, id: \.id) { serving in
                                                Text("\((serving.quantity ?? 1).formatted()) \(serving.unit ?? "serving")").tag(serving)
                                            }
                                        }
                                        .labelsHidden()
                                        .tint(AppPalette.muted)
                                    }
                                    Spacer(minLength: 4)
                                    Button("Decrease quantity", systemImage: "minus") {
                                        if item.quantity <= 0.25 {
                                            foods.removeAll { $0.id == item.id }
                                        } else {
                                            item.quantity -= 0.25
                                        }
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(QuantityButtonStyle())
                                    Text(item.quantity.formatted(.number.precision(.fractionLength(0...2))))
                                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                        .monospacedDigit()
                                        .frame(width: 48)
                                    Button("Increase quantity", systemImage: "plus") {
                                        item.quantity += 0.25
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(QuantityButtonStyle(isPrimary: true))
                                }
                                .padding(.vertical, 10)
                            }

                            Divider()
                            Button("Add food to prediction", systemImage: "plus") {
                                isShowingFoodPicker = true
                            }
                            .font(.headline)
                            .foregroundStyle(AppPalette.goldText)
                            .padding(.vertical, 12)

                        }
                    }

                    if let error {
                        ErrorNotice(error: error) { Task { await predict() } }
                    }

                    PrimaryButton(
                        title: "Estimate glucose response",
                        isLoading: isLoading,
                        isDisabled: foods.isEmpty
                    ) {
                        Task { await predict() }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 88)
        }
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
        .appNavigationBar("Glucose", style: .leading) {
            EmptyView()
        } trailing: {
            AppNavigationButton(.settings, action: settingsAction)
        }
    }

    private var conditionSummary: String {
        switch conditions.count {
        case 0: "None"
        case 1: "1 selected"
        default: "\(conditions.count) selected"
        }
    }

    private func formSection<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(title)
            if let detail {
                Text(detail)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content()
                .appCard()
        }
    }

    private func measurementRow(
        _ title: String,
        value: Binding<Double>,
        unit: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppPalette.ink)
            Spacer(minLength: 12)
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(AppTypography.metric)
                .monospacedDigit()
                .frame(width: 72)
            Text(unit)
                .font(.system(size: 14))
                .foregroundStyle(AppPalette.muted)
                .fixedSize()
        }
        .padding(.vertical, 12)
    }

    @MainActor private func predict() async {
        guard !foods.isEmpty else { return }
        isLoading = true; error = nil
        do {
            let request = PredictGlucoseRequest(
                userProfile: .init(
                    age: age,
                    sex: sex,
                    height: .init(value: height, unit: .inches),
                    weight: .init(value: weight, unit: .pounds),
                    activityLevel: nil,
                    healthConditions: Array(conditions)
                ),
                foods: foods.map(\.selection),
                startTime: startTime
            )
            prediction = try await client.glucose.predict(request)
        } catch { self.error = error }
        isLoading = false
    }
}

private struct ConditionSelectionView: View {
    @Binding var selection: Set<MedicalCondition>

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select all that apply. Leave both unselected if neither condition applies.")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)

                    VStack(spacing: 0) {
                        condition("Type 2 diabetes", .type2Diabetes)
                        Divider()
                        condition("Prediabetes", .prediabetes)
                    }
                    .appCard()
                }
            }
            .padding(.vertical, 16)
        }
        .appBackground()
        .appNavigationBar("Health conditions", style: .leading)
    }

    private func condition(_ label: String, _ value: MedicalCondition) -> some View {
        Button {
            if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
        } label: {
            HStack(spacing: 12) {
                Text(label)
                Spacer(minLength: 12)
                Image(systemName: selection.contains(value) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection.contains(value) ? AppPalette.green : AppPalette.border)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppPalette.ink)
        .accessibilityValue(selection.contains(value) ? "Selected" : "Not selected")
    }
}

private struct GlucoseResultView: View {
    let prediction: GlucosePrediction
    let foods: [SelectedFood]
    let adjust: () -> Void
    let startOver: () -> Void

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                    PredictionChart(
                        points: chartPoints,
                        lowerBound: prediction.minimum,
                        upperBound: prediction.maximum,
                        lineColor: chartColor,
                        summaryValue: peakPoint?.value,
                        summaryDetail: "\(impactLabel.lowercased()) · \(peakWindow)",
                        summaryDelta: deltaSummary,
                        showsPeakAnnotation: false
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(foods.enumerated()), id: \.element.id) { index, food in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(food.food.name ?? "Unnamed food")
                                        .font(AppTypography.bodyStrong)
                                    Text("\((food.serving.quantity ?? 1).formatted()) \(food.serving.unit ?? "serving") · quantity \(food.quantity.formatted())")
                                        .font(.system(size: 14))
                                        .foregroundStyle(AppPalette.muted)
                                }
                                Spacer(minLength: 8)
                                if index == 0 {
                                    Text(deltaValue)
                                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                                        .monospacedDigit()
                                        .foregroundStyle(chartColor)
                                }
                            }
                        }
                    }
                    .appCard()

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Worth knowing", color: AppPalette.goldText)
                            .padding(.horizontal, 0)
                        Text("This estimate reflects the foods, servings, and profile entered above. Adjusting the meal will generate a new prediction. It does not create or update a food log.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppPalette.ink)
                    }
                    .padding(AppSpacing.card)
                    .background(AppPalette.goldBackground, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                            .stroke(Color(red: 217 / 255, green: 194 / 255, blue: 95 / 255), lineWidth: 1.5)
                    }

                    Text("This is a prediction, not a medical recommendation.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.muted)

                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        Button("Adjust meal", action: adjust)
                            .buttonStyle(SecondaryButtonStyle())
                        PrimaryButton(title: "Start over", action: startOver)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 88)
        }
        .appBackground()
        .appNavigationBar("Estimated response") {
            AppNavigationButton(.back, title: "Glucose", action: adjust)
        } trailing: {
            EmptyView()
        }
    }

    private var chartPoints: [ChartPoint] {
        prediction.curve.compactMap { point in
            guard point.count >= 2 else { return nil }
            return ChartPoint(minutes: point[0], value: point[1])
        }
    }

    private var peakPoint: ChartPoint? {
        chartPoints.max { $0.value < $1.value }
    }

    private var mealPoint: ChartPoint? {
        chartPoints.min { $0.minutes < $1.minutes }
    }

    private var delta: Double {
        max(0, (peakPoint?.value ?? 0) - (mealPoint?.value ?? 0))
    }

    private var deltaValue: String {
        "+\(delta.formatted(.number.precision(.fractionLength(0))))"
    }

    private var deltaSummary: String {
        "\(deltaValue) above meal start"
    }

    private var peakWindow: String {
        guard let minutes = peakPoint?.minutes else { return "estimated timing" }
        let lower = max(0, Int(minutes.rounded()) - 15)
        let upper = Int(minutes.rounded()) + 15
        return "\(lower)–\(upper) min"
    }

    private var impactLabel: String {
        if prediction.scoring == .lowImpact { return "Low impact" }
        if prediction.scoring == .mediumImpact { return "Medium impact" }
        if prediction.scoring == .highImpact { return "High impact" }
        return prediction.scoring?.rawValue.capitalized ?? "Unknown impact"
    }
    private var chartColor: Color {
        prediction.scoring == .lowImpact ? AppPalette.green : AppPalette.rust
    }
}
