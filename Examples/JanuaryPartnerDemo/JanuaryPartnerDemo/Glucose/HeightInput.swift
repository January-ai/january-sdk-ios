import SwiftUI

enum HeightDisplayUnit: String, CaseIterable {
    case imperial
    case metric

    var title: String {
        switch self {
        case .imperial: "ft + in"
        case .metric: "cm"
        }
    }
}

struct HeightInput: View {
    @Binding var heightInches: Double
    @State private var displayUnit = HeightDisplayUnit.imperial

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Height")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppPalette.ink)
                Spacer(minLength: 12)
                SegmentedControl(HeightDisplayUnit.allCases, selection: $displayUnit) { $0.title }
                    .frame(maxWidth: 170)
                    .accessibilityLabel("Height units")
            }

            if displayUnit == .imperial {
                HStack(spacing: 12) {
                    valueField("Feet") {
                        EndAlignedNumberField(
                            value: String(imperialHeight.feet),
                            allowsDecimal: false
                        ) { value in
                            if let value = Int(value) { feet.wrappedValue = value }
                        }
                    }
                    valueField("Inches") {
                        EndAlignedNumberField(
                            value: String(imperialHeight.inches),
                            allowsDecimal: false
                        ) { value in
                            if let value = Int(value) { inches.wrappedValue = value }
                        }
                    }
                }
            } else {
                valueField("Centimeters") {
                    EndAlignedNumberField(
                        value: formatNumber(centimeters.wrappedValue),
                        allowsDecimal: true
                    ) { value in
                        if let value = Double(value) { centimeters.wrappedValue = value }
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var feet: Binding<Int> {
        Binding(
            get: { imperialHeight.feet },
            set: { newFeet in
                heightInches = clampedHeight(Double(newFeet * 12 + imperialHeight.inches))
            }
        )
    }

    private var inches: Binding<Int> {
        Binding(
            get: { imperialHeight.inches },
            set: { newInches in
                heightInches = clampedHeight(Double(imperialHeight.feet * 12 + newInches))
            }
        )
    }

    private var centimeters: Binding<Double> {
        Binding(
            get: { (heightInches * 25.4).rounded() / 10 },
            set: { heightInches = clampedHeight($0 / 2.54) }
        )
    }

    private var imperialHeight: (feet: Int, inches: Int) {
        let totalInches = Int(heightInches.rounded())
        return (totalInches / 12, totalInches % 12)
    }

    private func clampedHeight(_ value: Double) -> Double {
        min(max(value, 36), 96)
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
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    @Previewable @State var height = 66.0
    HeightInput(heightInches: $height)
        .padding()
        .background(AppPalette.paper)
}
