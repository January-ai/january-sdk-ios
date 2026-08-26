import SwiftUI

struct WorkflowGuideCard: View {
    let title: String
    let message: String
    let steps: [String]
    var symbol = "arrow.triangle.branch"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppPalette.green)
                    .frame(width: 44, height: 44)
                    .background(AppPalette.targetBand, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppPalette.ink)
                    Text(message)
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(AppPalette.greenText)
                            .frame(width: 24, height: 24)
                            .background(AppPalette.targetBand, in: Circle())
                        Text(step)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppPalette.ink)
                    }
                }
            }
        }
        .appCard()
    }
}

#Preview("Workflow guide") {
    WorkflowGuideCard(
        title: "Build one complete meal",
        message: "A food log groups every food and serving consumed at one time.",
        steps: [
            "Identify the user",
            "Add every food in the meal",
            "Save the completed log"
        ],
        symbol: "list.bullet.clipboard"
    )
    .padding()
    .background(AppPalette.paper)
}
