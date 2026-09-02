import January
import SwiftUI

enum AppPalette {
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

enum AppSpacing {
    static let screen: CGFloat = 16
    static let sheetTop: CGFloat = 28
    static let section: CGFloat = 20
    static let card: CGFloat = 22
    static let rowVertical: CGFloat = 14
    static let controlHorizontal: CGFloat = 18
}

enum AppRadius {
    static let control: CGFloat = 18
    static let card: CGFloat = 24
    static let feature: CGFloat = 28
}

enum AppTypography {
    static let screenTitle = Font.system(size: 32, weight: .regular, design: .serif)
    static let sheetTitle = Font.system(size: 28, weight: .regular, design: .serif)
    static let cardTitle = Font.system(size: 24, weight: .regular, design: .serif)
    static let navigationTitle = Font.headline
    static let body = Font.system(size: 17)
    static let bodyStrong = Font.system(size: 17, weight: .semibold)
    static let metric = Font.system(size: 20, weight: .semibold, design: .monospaced)
    static let eyebrow = Font.system(size: 13, weight: .bold)
}

struct SelectedFood: Identifiable, Hashable {
    let id = UUID()
    let food: FoodSearchItem
    var serving: ServingOption
    var quantity: Double

    var selection: FoodSelection {
        guard let servingID = serving.id else {
            preconditionFailure("Selected foods must have a serving ID.")
        }
        return FoodSelection(id: food.id, serving: ServingSelection(id: servingID, quantity: quantity))
    }
}

enum AppFormatting {
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

    static func apiDayString(from date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func endUserID(_ raw: String) -> PartnerUserID? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : PartnerUserID(rawValue: value)
    }
}

struct NutrientRow: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String
}

struct ChartPoint: Identifiable {
    let minutes: Double
    let value: Double

    var id: Double { minutes }
}
