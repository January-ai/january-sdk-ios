import JanuaryPartnerSDK
import SwiftUI

struct GlucoseView: View {
    let client: JanuaryPartnerClient
    let settingsAction: () -> Void

    @AppStorage("demo.endUserID") private var endUserID = ""
    @AppStorage("demo.timezone") private var timezone = TimeZone.current.identifier
    @State private var age = 42.0
    @State private var sex = Sex.female
    @State private var height = 66.0
    @State private var weight = 150.0
    @State private var conditions: Set<MedicalCondition> = []
    @State private var foods: [DemoSelectedFood] = []
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
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingFoodPicker) {
                FoodPickerView(client: client, endUserID: DemoFormatting.endUserID(endUserID)) { selected in
                    foods.append(selected); isShowingFoodPicker = false
                }
            }
        }
    }

    private var predictionForm: some View {
        ScrollView {
            DemoScreenShell {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Glucose")
                        .font(DemoTypography.screenTitle)
                        .foregroundStyle(DemoPalette.ink)

                    formSection("About you") {
                        VStack(spacing: 0) {
                            measurementRow("Age", value: $age, unit: "years")
                            Divider()

                            HStack(spacing: 16) {
                                Text("Sex")
                                    .font(DemoTypography.bodyStrong)
                                    .foregroundStyle(DemoPalette.ink)
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
                            measurementRow("Height", value: $height, unit: "in")
                            Divider()
                            measurementRow("Weight", value: $weight, unit: "lb")
                            Divider()
                            NavigationLink {
                                ConditionSelectionView(selection: $conditions)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("Health conditions")
                                        .foregroundStyle(DemoPalette.ink)
                                    Spacer(minLength: 12)
                                    Text(conditionSummary)
                                        .foregroundStyle(DemoPalette.muted)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                        }
                    }

                    formSection("This meal") {
                        VStack(spacing: 0) {
                            DatePicker("Start time", selection: $startTime)
                                .padding(.vertical, 8)

                            ForEach($foods) { $item in
                                Divider()
                                HStack(spacing: 10) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.food.name)
                                            .font(DemoTypography.bodyStrong)
                                            .foregroundStyle(DemoPalette.ink)
                                        Picker("Serving", selection: $item.serving) {
                                            ForEach(item.food.servings, id: \.id) { serving in
                                                Text("\(serving.quantity.formatted()) \(serving.unit)").tag(serving)
                                            }
                                        }
                                        .labelsHidden()
                                        .tint(DemoPalette.muted)
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
                                    .buttonStyle(DemoQuantityButtonStyle())
                                    Text(item.quantity.formatted(.number.precision(.fractionLength(0...2))))
                                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                                        .monospacedDigit()
                                        .frame(width: 48)
                                    Button("Increase quantity", systemImage: "plus") {
                                        item.quantity += 0.25
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(DemoQuantityButtonStyle(isPrimary: true))
                                }
                                .padding(.vertical, 10)
                            }

                            Divider()
                            Button("Add food", systemImage: "plus") {
                                isShowingFoodPicker = true
                            }
                            .font(.headline)
                            .foregroundStyle(DemoPalette.goldText)
                            .padding(.vertical, 12)

                        }
                    }

                    if let error {
                        DemoErrorNotice(error: error) { Task { await predict() } }
                    }

                    Button {
                        Task { await predict() }
                    } label: {
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Predict glucose response")
                        }
                    }
                    .buttonStyle(DemoPrimaryButtonStyle())
                    .disabled(foods.isEmpty || isLoading)
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 88)
        }
        .scrollDismissesKeyboard(.interactively)
        .demoBackground()
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            DemoSectionLabel(title)
            content()
                .demoCard()
        }
    }

    private func measurementRow(
        _ title: String,
        value: Binding<Double>,
        unit: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(DemoTypography.bodyStrong)
                .foregroundStyle(DemoPalette.ink)
            Spacer(minLength: 12)
            TextField(title, value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(DemoTypography.metric)
                .monospacedDigit()
                .frame(width: 72)
            Text(unit)
                .font(.system(size: 14))
                .foregroundStyle(DemoPalette.muted)
                .fixedSize()
        }
        .padding(.vertical, 12)
    }

    @MainActor private func predict() async {
        guard !foods.isEmpty else { return }
        isLoading = true; error = nil
        do {
            prediction = try await client.glucose.predict(.init(
                userProfile: .init(
                    age: age,
                    sex: sex,
                    height: .init(value: height, unit: .inches),
                    weight: .init(value: weight, unit: .pounds),
                    activityLevel: nil,
                    healthConditions: Array(conditions)
                ),
                foods: foods.map(\.selection),
                startTime: startTime,
                endUserID: DemoFormatting.endUserID(endUserID),
                timezone: timezone
            ))
        } catch { self.error = error }
        isLoading = false
    }
}

private struct ConditionSelectionView: View {
    @Binding var selection: Set<MedicalCondition>

    var body: some View {
        ScrollView {
            DemoScreenShell {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Select all that apply. Leave both unselected if neither condition applies.")
                        .font(.subheadline)
                        .foregroundStyle(DemoPalette.muted)

                    VStack(spacing: 0) {
                        condition("Type 2 diabetes", .type2Diabetes)
                        Divider()
                        condition("Prediabetes", .prediabetes)
                    }
                    .demoCard()
                }
            }
            .padding(.vertical, 16)
        }
        .demoBackground()
        .navigationTitle("Health conditions")
        .navigationBarTitleDisplayMode(.large)
    }

    private func condition(_ label: String, _ value: MedicalCondition) -> some View {
        Button {
            if selection.contains(value) { selection.remove(value) } else { selection.insert(value) }
        } label: {
            DemoFillWidth {
                HStack(spacing: 12) {
                    Text(label)
                    Spacer(minLength: 12)
                    Image(systemName: selection.contains(value) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selection.contains(value) ? DemoPalette.green : DemoPalette.border)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(DemoPalette.ink)
        .accessibilityValue(selection.contains(value) ? "Selected" : "Not selected")
    }
}

private struct GlucoseResultView: View {
    let prediction: GlucosePrediction
    let foods: [DemoSelectedFood]
    let adjust: () -> Void
    let startOver: () -> Void

    var body: some View {
        ScrollView {
            DemoScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                    Button("Glucose", systemImage: "chevron.left", action: adjust)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DemoPalette.goldText)
                    Text("Estimated response")
                        .font(DemoTypography.screenTitle)
                        .foregroundStyle(DemoPalette.ink)

                    DemoPredictionChart(
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
                                    Text(food.food.name)
                                        .font(DemoTypography.bodyStrong)
                                    Text("\(food.serving.quantity.formatted()) \(food.serving.unit) · quantity \(food.quantity.formatted())")
                                        .font(.system(size: 14))
                                        .foregroundStyle(DemoPalette.muted)
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
                    .demoCard()

                    VStack(alignment: .leading, spacing: 8) {
                        DemoSectionLabel("Worth knowing", color: DemoPalette.goldText)
                            .padding(.horizontal, 0)
                        Text("This estimate reflects the foods, servings, and profile entered above. Adjusting the meal will generate a new prediction.")
                            .font(DemoTypography.body)
                            .foregroundStyle(DemoPalette.ink)
                    }
                    .padding(DemoSpacing.card)
                    .background(DemoPalette.goldBackground, in: RoundedRectangle(cornerRadius: DemoRadius.card, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DemoRadius.card, style: .continuous)
                            .stroke(Color(red: 217 / 255, green: 194 / 255, blue: 95 / 255), lineWidth: 1.5)
                    }

                    Text("This is a prediction, not a medical recommendation.")
                        .font(.footnote)
                        .foregroundStyle(DemoPalette.muted)

                    DemoEqualColumns(spacing: 10) {
                        Button("Adjust meal", action: adjust)
                            .buttonStyle(DemoSecondaryButtonStyle())
                        Button("Start over", action: startOver)
                            .buttonStyle(DemoPrimaryButtonStyle())
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 88)
        }.demoBackground()
    }

    private var chartPoints: [DemoChartPoint] {
        prediction.curve.compactMap { point in
            guard point.count >= 2 else { return nil }
            return DemoChartPoint(minutes: point[0], value: point[1])
        }
    }

    private var peakPoint: DemoChartPoint? {
        chartPoints.max { $0.value < $1.value }
    }

    private var mealPoint: DemoChartPoint? {
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
        return prediction.scoring.rawValue.capitalized
    }
    private var chartColor: Color {
        prediction.scoring == .lowImpact ? DemoPalette.green : DemoPalette.rust
    }
}
