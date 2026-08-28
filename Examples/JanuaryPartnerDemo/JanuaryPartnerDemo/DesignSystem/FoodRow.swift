import January
import SwiftUI

struct FoodRow: View {
    let food: FoodSearchItem
    var isLoading = false

    var body: some View {
        HStack(spacing: 14) {
            NetworkImage(
                url: food.photoURL,
                placeholder: Image(systemName: "fork.knife")
            )
            .foregroundStyle(AppPalette.green)
            .frame(width: 58, height: 58)
            .background(AppPalette.control)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.headline).foregroundStyle(AppPalette.ink)
                if let brand = food.brandName, !brand.isEmpty {
                    Text(brand).font(.subheadline).foregroundStyle(AppPalette.muted)
                }
                HStack(spacing: 10) {
                    if let calories = food.calories {
                        Text("\(calories.formatted(.number.precision(.fractionLength(0)))) cal")
                    }
                    if let serving = food.servings.first(where: \.isPrimary) ?? food.servings.first {
                        Text("\(serving.quantity.formatted()) \(serving.unit)")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppPalette.muted)
            }
            Spacer(minLength: 4)
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppPalette.muted)
            } else {
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    FoodRow(
        food: FoodSearchItem(
            id: FoodID(rawValue: 1),
            name: "Margherita pizza",
            brandName: "Demo kitchen",
            calories: 285,
            servings: [
                ServingOption(id: ServingID(rawValue: 1), quantity: 1, unit: "slice", scalingFactor: 1, isPrimary: true)
            ]
        )
    )
    .padding()
    .background(AppPalette.paper)
}
