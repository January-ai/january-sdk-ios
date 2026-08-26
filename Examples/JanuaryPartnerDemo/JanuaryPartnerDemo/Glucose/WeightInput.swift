import SwiftUI

enum WeightDisplayUnit: String, CaseIterable {
    case pounds
    case kilograms

    var title: String {
        switch self {
        case .pounds: "lb"
        case .kilograms: "kg"
        }
    }
}

struct WeightInput: View {
    @Binding var weightPounds: Double
    @State private var displayUnit = WeightDisplayUnit.pounds

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Weight")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppPalette.ink)
                Spacer(minLength: 12)
                SegmentedControl(WeightDisplayUnit.allCases, selection: $displayUnit) { $0.title }
                    .frame(maxWidth: 170)
                    .accessibilityLabel("Weight units")
            }

            valueField(displayUnit == .pounds ? "Pounds" : "Kilograms") {
                EndAlignedNumberField(
                    value: formatNumber(displayedWeight.wrappedValue),
                    allowsDecimal: true
                ) { value in
                    if let value = Double(value) { displayedWeight.wrappedValue = value }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var displayedWeight: Binding<Double> {
        Binding(
            get: {
                let value = displayUnit == .pounds ? weightPounds : weightPounds * 0.45359237
                return (value * 10).rounded() / 10
            },
            set: { value in
                let pounds = displayUnit == .pounds ? value : value / 0.45359237
                weightPounds = min(max(pounds, 60), 700)
            }
        )
    }

    private func formatNumber(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private func valueField<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.muted)
            content()
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppPalette.control, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

#Preview {
    @Previewable @State var weight = 150.0
    WeightInput(weightPounds: $weight)
        .padding()
        .background(AppPalette.paper)
}
