import SwiftUI

struct FoodLogTimeSpanPicker: View {
    @Binding var selection: FoodLogTimeSpan
    let range: FoodLogDateRange
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SegmentedControl(FoodLogTimeSpan.allCases, selection: $selection) { $0.title }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Dates")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppPalette.ink)
                Spacer(minLength: 12)
                Text(range.displayText(calendar: calendar))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppPalette.muted)
                    .multilineTextAlignment(.trailing)
            }
        }
        .appCard()
    }
}

private struct FoodLogTimeSpanPickerPreview: View {
    @State private var selection = FoodLogTimeSpan.currentWeek

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        return calendar
    }

    var body: some View {
        FoodLogTimeSpanPicker(
            selection: $selection,
            range: selection.dateRange(calendar: calendar),
            calendar: calendar
        )
        .padding()
        .background(AppPalette.paper)
    }
}

#Preview("Food log time spans") {
    FoodLogTimeSpanPickerPreview()
}
