import JanuaryPartnerSDK
import Charts
import SwiftUI

enum DemoPalette {
    static let canvas = Color(red: 239 / 255, green: 235 / 255, blue: 226 / 255)
    static let paper = Color(red: 250 / 255, green: 248 / 255, blue: 242 / 255)
    static let surface = Color.white
    static let ink = Color(red: 29 / 255, green: 26 / 255, blue: 20 / 255)
    static let body = Color(red: 62 / 255, green: 58 / 255, blue: 46 / 255)
    static let muted = Color(red: 85 / 255, green: 80 / 255, blue: 63 / 255)
    static let subdued = Color(red: 143 / 255, green: 136 / 255, blue: 122 / 255)
    static let border = Color(red: 224 / 255, green: 218 / 255, blue: 203 / 255)
    static let divider = Color(red: 241 / 255, green: 237 / 255, blue: 226 / 255)
    static let control = Color(red: 243 / 255, green: 240 / 255, blue: 231 / 255)
    static let controlStrong = Color(red: 235 / 255, green: 229 / 255, blue: 216 / 255)
    static let yellow = Color(red: 244 / 255, green: 198 / 255, blue: 63 / 255)
    static let green = Color(red: 84 / 255, green: 114 / 255, blue: 79 / 255)
    static let rust = Color(red: 168 / 255, green: 95 / 255, blue: 61 / 255)
    static let targetBand = Color(red: 240 / 255, green: 243 / 255, blue: 234 / 255)
    static let greenText = Color(red: 62 / 255, green: 90 / 255, blue: 58 / 255)
    static let goldText = Color(red: 110 / 255, green: 86 / 255, blue: 19 / 255)
    static let goldBackground = Color(red: 251 / 255, green: 240 / 255, blue: 203 / 255)
    static let rustText = Color(red: 140 / 255, green: 74 / 255, blue: 47 / 255)
    static let rustBackground = Color(red: 250 / 255, green: 235 / 255, blue: 225 / 255)
}

enum DemoSpacing {
    static let screen: CGFloat = 16
    static let sheetTop: CGFloat = 28
    static let section: CGFloat = 20
    static let card: CGFloat = 22
    static let rowVertical: CGFloat = 14
    static let controlHorizontal: CGFloat = 18
}

enum DemoRadius {
    static let control: CGFloat = 18
    static let card: CGFloat = 24
    static let feature: CGFloat = 28
}

enum DemoTypography {
    static let screenTitle = Font.system(size: 32, weight: .regular, design: .serif)
    static let sheetTitle = Font.system(size: 28, weight: .regular, design: .serif)
    static let cardTitle = Font.system(size: 24, weight: .regular, design: .serif)
    static let body = Font.system(size: 17)
    static let bodyStrong = Font.system(size: 17, weight: .semibold)
    static let metric = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let eyebrow = Font.system(size: 13, weight: .bold)
}

struct DemoCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DemoSpacing.card)
            .background(DemoPalette.surface, in: RoundedRectangle(cornerRadius: DemoRadius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DemoRadius.card, style: .continuous)
                    .stroke(DemoPalette.ink.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: DemoPalette.ink.opacity(0.08), radius: 20, y: 10)
    }
}

extension View {
    func demoCard() -> some View { modifier(DemoCard()) }

    func demoBackground() -> some View {
        background(DemoPalette.paper)
    }
}

/// The single horizontal layout boundary for every demo screen.
struct DemoScreenShell<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        DemoFillWidth {
            content
        }
        .padding(.horizontal, DemoSpacing.screen)
    }
}

/// Makes flexible content consume its finite parent proposal without using an
/// unbounded frame.
struct DemoFillWidth: Layout {
    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let measured = content.sizeThatFits(proposal)
        return CGSize(
            width: proposal.width ?? measured.width,
            height: proposal.height ?? measured.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        subviews.first?.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height)
        )
    }
}

/// Distributes a finite parent width evenly across its children.
struct DemoEqualColumns: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let proposedWidth = proposal.width ?? 0
        let available = max(0, proposedWidth - spacing * CGFloat(subviews.count - 1))
        let columnWidth = available / CGFloat(subviews.count)
        let heights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: proposal.height)).height
        }
        return CGSize(width: proposedWidth, height: heights.max() ?? 0)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }
        let available = max(0, bounds.width - spacing * CGFloat(subviews.count - 1))
        let columnWidth = available / CGFloat(subviews.count)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + CGFloat(index) * (columnWidth + spacing), y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: columnWidth, height: bounds.height)
            )
        }
    }
}

struct DemoPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 16)
            configuration.label
                .font(DemoTypography.bodyStrong)
                .foregroundStyle(isEnabled ? DemoPalette.paper : DemoPalette.subdued)
            Spacer(minLength: 16)
        }
            .frame(minHeight: 56)
            .background(
                (isEnabled ? DemoPalette.ink : DemoPalette.control).opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct DemoSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 12)
            configuration.label
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isEnabled ? DemoPalette.ink : DemoPalette.subdued)
            Spacer(minLength: 12)
        }
        .frame(minHeight: 54)
        .background(
            DemoPalette.control.opacity(configuration.isPressed ? 0.75 : 1),
            in: RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous)
        )
    }
}

struct DemoOutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 0) {
            Spacer(minLength: 12)
            configuration.label
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DemoPalette.ink)
            Spacer(minLength: 12)
        }
        .frame(minHeight: 52)
        .background(DemoPalette.surface, in: RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous)
                .stroke(DemoPalette.border, lineWidth: 1.5)
        }
        .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct DemoQuantityButtonStyle: ButtonStyle {
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isPrimary ? DemoPalette.paper : DemoPalette.ink)
            .frame(width: 56, height: 56)
            .background(
                (isPrimary ? DemoPalette.ink : DemoPalette.control).opacity(configuration.isPressed ? 0.72 : 1),
                in: Circle()
            )
            .overlay {
                if !isPrimary {
                    Circle().stroke(DemoPalette.border, lineWidth: 1.5)
                }
            }
    }
}

struct DemoChipButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isSelected ? DemoPalette.paper : DemoPalette.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(
                isSelected ? DemoPalette.ink : DemoPalette.surface,
                in: RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous)
            )
            .overlay {
                if !isSelected {
                    RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous)
                        .stroke(DemoPalette.border, lineWidth: 1.5)
                }
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct DemoSegmentedControl<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    init(
        _ options: [Option],
        selection: Binding<Option>,
        label: @escaping (Option) -> String
    ) {
        self.options = options
        _selection = selection
        self.label = label
    }

    var body: some View {
        DemoEqualColumns(spacing: 5) {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    DemoFillWidth {
                        HStack(spacing: 0) {
                            Spacer(minLength: 8)
                            Text(label(option))
                                .font(.system(size: 14, weight: .bold))
                            Spacer(minLength: 8)
                        }
                        .frame(minHeight: 40)
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(selection == option ? DemoPalette.ink : DemoPalette.muted)
                    .background(
                        selection == option ? DemoPalette.surface : Color.clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: selection == option ? DemoPalette.ink.opacity(0.05) : .clear, radius: 7, y: 2)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }
        .padding(5)
        .background(DemoPalette.controlStrong, in: RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous))
    }
}

struct DemoSectionLabel: View {
    let title: String
    let color: Color

    init(_ title: String, color: Color = DemoPalette.muted) {
        self.title = title
        self.color = color
    }

    var body: some View {
        Text(title.uppercased())
            .font(DemoTypography.eyebrow)
            .tracking(1.15)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

struct DemoSearchField: View {
    let prompt: String
    @Binding var text: String
    var submit: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(DemoPalette.muted)
            TextField(prompt, text: $text)
                .font(DemoTypography.body)
                .submitLabel(.search)
                .onSubmit { submit?() }
            if !text.isEmpty {
                Button("Clear search", systemImage: "xmark.circle.fill") { text = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(DemoPalette.subdued)
            }
        }
        .padding(.horizontal, DemoSpacing.controlHorizontal)
        .frame(minHeight: 56)
        .background(DemoPalette.control, in: RoundedRectangle(cornerRadius: DemoRadius.control, style: .continuous))
    }
}

struct DemoEmptyStateCard: View {
    let title: String
    let message: String
    let symbol: String
    var usesSerifSymbol = false

    var body: some View {
        DemoFillWidth {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    if usesSerifSymbol {
                        Text(symbol)
                            .font(.system(size: 22, design: .serif))
                            .foregroundStyle(DemoPalette.muted)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(DemoPalette.green)
                    }
                    Text(title)
                        .font(DemoTypography.cardTitle)
                        .foregroundStyle(DemoPalette.ink)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(DemoTypography.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DemoPalette.body)
                }
                .padding(.horizontal, 20)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 34)
            .background(DemoPalette.surface, in: RoundedRectangle(cornerRadius: DemoRadius.feature, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DemoRadius.feature, style: .continuous)
                    .stroke(DemoPalette.border, lineWidth: 1.5)
            }
        }
    }
}

struct DemoToolbarSettingsButton: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Settings", systemImage: "gearshape", action: action)
                .accessibilityIdentifier("settingsButton")
        }
    }
}

struct DemoErrorNotice: View {
    let error: Error
    var retry: (() -> Void)?

    private var title: String {
        guard let januaryError = error as? JanuaryError else { return "Couldn’t complete that request" }
        switch januaryError.category {
        case .authentication, .authorization: return "Couldn’t use the configured API key"
        case .validation: return "Check the information you entered"
        case .notFound: return "No matching result was found"
        case .rateLimited: return "Too many requests"
        case .timeout: return "The request took too long"
        case .transport: return "Check your connection"
        case .server, .decoding: return "January couldn’t complete the request"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "exclamationmark.circle")
                .font(.headline)
                .foregroundStyle(DemoPalette.rust)
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(DemoPalette.body)
            if let januaryError = error as? JanuaryError,
               januaryError.requestID != nil || januaryError.httpStatus != nil {
                DisclosureGroup("Technical details") {
                    if let status = januaryError.httpStatus { LabeledContent("HTTP status", value: "\(status)") }
                    if let code = januaryError.code { LabeledContent("Error code", value: code) }
                    if let requestID = januaryError.requestID { LabeledContent("Request ID", value: requestID) }
                }
                .font(.footnote)
            }
            if let retry {
                Button("Try again", action: retry)
                    .font(.headline)
            }
        }
        .demoCard()
        .accessibilityElement(children: .contain)
    }
}

struct DemoFoodRow: View {
    let food: FoodSearchItem

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: food.photoURL.flatMap(URL.init(string:))) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "fork.knife")
                    .foregroundStyle(DemoPalette.green)
            }
            .frame(width: 58, height: 58)
            .background(DemoPalette.control)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.headline).foregroundStyle(DemoPalette.ink)
                if let brand = food.brandName, !brand.isEmpty {
                    Text(brand).font(.subheadline).foregroundStyle(DemoPalette.muted)
                }
                HStack(spacing: 10) {
                    if let calories = food.calories { Text("\(calories.formatted(.number.precision(.fractionLength(0)))) cal") }
                    if let serving = food.servings.first(where: \.isPrimary) ?? food.servings.first {
                        Text("\(serving.quantity.formatted()) \(serving.unit)")
                    }
                }
                .font(.caption)
                .foregroundStyle(DemoPalette.muted)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

struct DemoMacroStrip: View {
    let calories: Double?
    let protein: Double?
    let carbohydrates: Double?
    let fat: Double?

    var body: some View {
        DemoFillWidth {
            HStack(spacing: 8) {
                if let calories { value("Calories", calories, "cal") }
                Spacer(minLength: 0)
                if let protein { value("Protein", protein, "g") }
                Spacer(minLength: 0)
                if let carbohydrates { value("Carbs", carbohydrates, "g") }
                Spacer(minLength: 0)
                if let fat { value("Fat", fat, "g") }
            }
        }
    }

    private func value(_ label: String, _ number: Double, _ unit: String) -> some View {
        VStack(spacing: 3) {
            Text(number.formatted(.number.precision(.fractionLength(0...1))))
                .font(.system(.title3, design: .monospaced, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(DemoPalette.ink)
            Text(unit).font(.caption2).foregroundStyle(DemoPalette.muted)
            Text(label).font(.caption2).foregroundStyle(DemoPalette.muted)
        }
    }
}

struct DemoNutrientRow: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String
}

struct DemoNutritionList: View {
    let rows: [DemoNutrientRow]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                LabeledContent(row.name, value: "\(row.value.formatted(.number.precision(.fractionLength(0...2)))) \(row.unit)")
                    .monospacedDigit()
                    .padding(.vertical, 10)
                if index < rows.count - 1 { Divider() }
            }
        }
    }
}

struct DemoSelectedFood: Identifiable, Hashable {
    let id = UUID()
    let food: FoodSearchItem
    var serving: ServingOption
    var quantity: Double

    var selection: FoodSelection {
        FoodSelection(id: food.id, serving: ServingSelection(id: serving.id, quantity: quantity))
    }
}

enum DemoFormatting {
    static let apiDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let apiDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func endUserID(_ raw: String) -> PartnerUserID? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : PartnerUserID(rawValue: value)
    }
}

struct DemoChartPoint: Identifiable {
    let minutes: Double
    let value: Double

    var id: Double { minutes }
}

struct DemoPredictionChart: View {
    let points: [DemoChartPoint]
    let lowerBound: Double?
    let upperBound: Double?
    let lineColor: Color
    var summaryValue: Double?
    var summaryDetail: String?
    var summaryDelta: String?
    var showsPeakAnnotation = true

    init(
        points: [DemoChartPoint],
        lowerBound: Double?,
        upperBound: Double?,
        lineColor: Color,
        summaryValue: Double? = nil,
        summaryDetail: String? = nil,
        summaryDelta: String? = nil,
        showsPeakAnnotation: Bool = true
    ) {
        self.points = points
        self.lowerBound = lowerBound
        self.upperBound = upperBound
        self.lineColor = lineColor
        self.summaryValue = summaryValue
        self.summaryDetail = summaryDetail
        self.summaryDelta = summaryDelta
        self.showsPeakAnnotation = showsPeakAnnotation
    }

    var body: some View {
        VStack(spacing: 0) {
            if let summaryValue {
                DemoFillWidth {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Likely peak")
                            .font(DemoTypography.eyebrow)
                            .tracking(1.1)
                            .textCase(.uppercase)
                            .foregroundStyle(DemoPalette.muted)
                        HStack(alignment: .lastTextBaseline, spacing: 9) {
                            Text(summaryValue.formatted(.number.precision(.fractionLength(0))))
                                .font(.system(size: 58, weight: .bold, design: .monospaced))
                                .monospacedDigit()
                                .foregroundStyle(lineColor)
                            if let summaryDetail {
                                Text(summaryDetail)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(DemoPalette.body)
                            }
                        }
                        if let summaryDelta {
                            Text(summaryDelta)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(lineColor)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 2)
            } else {
                DemoFillWidth {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Predicted response")
                            .font(.caption.weight(.bold))
                            .tracking(1.1)
                            .textCase(.uppercase)
                            .foregroundStyle(DemoPalette.muted)
                        Spacer(minLength: 12)
                        Text("mg/dL")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(DemoPalette.muted)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 8)
            }

            Chart {
                if let lowerBound, let upperBound {
                    RectangleMark(
                        yStart: .value("Target minimum", lowerBound),
                        yEnd: .value("Target maximum", upperBound)
                    )
                    .foregroundStyle(DemoPalette.targetBand)
                }

                ForEach(displayPoints) { point in
                    AreaMark(
                        x: .value("Minutes", point.minutes),
                        yStart: .value("Chart baseline", fillBaseline),
                        yEnd: .value("Predicted glucose", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [lineColor.opacity(0.24), lineColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Minutes", point.minutes),
                        y: .value("Predicted glucose", point.value)
                    )
                    .foregroundStyle(lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .interpolationMethod(.catmullRom)
                }

                if let mealPoint {
                    PointMark(
                        x: .value("Meal", mealPoint.minutes),
                        y: .value("Meal glucose", mealPoint.value)
                    )
                    .symbol {
                        Circle()
                            .fill(DemoPalette.yellow)
                            .stroke(DemoPalette.ink, lineWidth: 2.5)
                            .frame(width: 18, height: 18)
                    }
                    .accessibilityLabel("Meal")
                }

                if let peakPoint {
                    PointMark(
                        x: .value("Peak time", peakMarkerMinutes),
                        y: .value("Peak glucose", peakPoint.value)
                    )
                    .symbol {
                        Circle()
                            .fill(Color.white)
                            .stroke(DemoPalette.ink, lineWidth: 2.5)
                            .frame(width: 16, height: 16)
                    }
                    .annotation(position: .topLeading, spacing: 10) {
                        if showsPeakAnnotation {
                            VStack(spacing: 1) {
                                Text("Likely peak")
                                    .font(.caption2.weight(.bold))
                                    .textCase(.uppercase)
                                    .tracking(0.7)
                                    .foregroundStyle(DemoPalette.muted)
                                Text("\(peakPoint.value.formatted(.number.precision(.fractionLength(0)))) · +\(peakPoint.minutes.formatted(.number.precision(.fractionLength(0)))) min")
                                    .font(.system(.headline, design: .monospaced, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(DemoPalette.ink)
                            }
                            .fixedSize()
                        }
                    }
                    .accessibilityLabel("Likely peak")
                    .accessibilityValue("\(peakPoint.value.formatted()) milligrams per deciliter, \(peakPoint.minutes.formatted()) minutes after the meal")
                }
            }
            .chartXScale(
                domain: xDomain,
                range: .plotDimension(startPadding: 18, endPadding: 0)
            )
            .chartYScale(domain: yDomain)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color.white)
            }
            .frame(height: 205)

            HStack {
                ForEach([0, 40, 80, 120], id: \.self) { minutes in
                    Text(minutes.formatted())
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(DemoPalette.muted)
                    if minutes != 120 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.top, 6)

            DemoFillWidth {
                HStack(spacing: 12) {
                    legendItem("Prediction") {
                        Capsule()
                            .fill(lineColor)
                            .frame(width: 24, height: 3.5)
                    }
                    legendItem("Meal") {
                        Circle()
                            .fill(DemoPalette.yellow)
                            .stroke(DemoPalette.ink, lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                    if lowerBound != nil, upperBound != nil {
                        legendItem("Target") {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(DemoPalette.targetBand)
                                .frame(width: 22, height: 12)
                        }
                    }
                    legendItem("Peak") {
                        Circle()
                            .fill(Color.white)
                            .stroke(DemoPalette.ink, lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(DemoPalette.border.opacity(0.75), lineWidth: 1)
        }
        .shadow(color: DemoPalette.ink.opacity(0.055), radius: 14, y: 7)
        .accessibilityLabel("Predicted glucose response chart")
        .accessibilityValue(chartAccessibilityValue)
    }

    private var mealPoint: DemoChartPoint? {
        displayPoints.min { $0.minutes < $1.minutes }
    }

    private var peakPoint: DemoChartPoint? {
        displayPoints.max { $0.value < $1.value }
    }

    private var peakMarkerMinutes: Double {
        min(peakPoint?.minutes ?? 0, 116)
    }

    private var xDomain: ClosedRange<Double> {
        0...120
    }

    private var yDomain: ClosedRange<Double> {
        var values = displayPoints.map(\.value)
        if let lowerBound { values.append(lowerBound) }
        if let upperBound { values.append(upperBound) }
        guard let minimum = values.min(), let maximum = values.max() else { return 50...180 }

        let span = max(maximum - minimum, 20)
        let lower = floor((minimum - max(12, span * 0.16)) / 10) * 10
        let upper = ceil((maximum + max(18, span * 0.24)) / 10) * 10
        return lower...upper
    }

    private var fillBaseline: Double {
        lowerBound ?? yDomain.lowerBound
    }

    private var displayPoints: [DemoChartPoint] {
        points
            .filter { (0...120).contains($0.minutes) }
            .sorted { $0.minutes < $1.minutes }
    }

    private var chartAccessibilityValue: String {
        guard let peakPoint else { return "No prediction points" }
        return "Likely peak \(peakPoint.value.formatted()) milligrams per deciliter at \(peakPoint.minutes.formatted()) minutes after the meal"
    }

    private func legendItem<Symbol: View>(
        _ title: String,
        @ViewBuilder symbol: () -> Symbol
    ) -> some View {
        HStack(spacing: 6) {
            symbol()
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(DemoPalette.body)
        }
    }
}
