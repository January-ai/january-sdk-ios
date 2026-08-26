import SwiftUI

struct FoodLogUserCard: View {
    let userID: String?
    let timezone: String
    let onSave: (String) -> Void
    let onSettings: () -> Void

    @State private var draftUserID: String

    init(
        userID: String?,
        timezone: String,
        onSave: @escaping (String) -> Void,
        onSettings: @escaping () -> Void
    ) {
        self.userID = userID
        self.timezone = timezone
        self.onSave = onSave
        self.onSettings = onSettings
        _draftUserID = State(initialValue: userID ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: userID == nil ? "person.crop.circle.badge.questionmark" : "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(AppPalette.goldText)

                VStack(alignment: .leading, spacing: 4) {
                    Text(userID == nil ? "Identify the user first" : "Logging for this user")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppPalette.ink)
                    Text(userID == nil
                         ? "Food logs are stored and fetched by your app’s stable user ID."
                         : "New logs and saved-log searches use this identity.")
                        .font(.system(size: 15))
                        .foregroundStyle(AppPalette.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let userID {
                VStack(alignment: .leading, spacing: 5) {
                    Text(userID)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppPalette.ink)
                        .textSelection(.enabled)
                    Text(timezone)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                }

                Button("Change user or timezone", action: onSettings)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.goldText)
            } else {
                TextField("Stable end user ID", text: $draftUserID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, design: .monospaced))
                    .padding(.horizontal, AppSpacing.controlHorizontal)
                    .frame(minHeight: 54)
                    .background(AppPalette.surface, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))

                PrimaryButton(
                    title: "Use this user ID",
                    isDisabled: normalizedUserID == nil
                ) {
                    if let normalizedUserID { onSave(normalizedUserID) }
                }

                Button("Set user ID and timezone in Settings", action: onSettings)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppPalette.goldText)
            }
        }
        .padding(AppSpacing.card)
        .background(AppPalette.goldBackground, in: RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.feature, style: .continuous)
                .stroke(AppPalette.goldText.opacity(0.28), lineWidth: 1.5)
        }
    }

    private var normalizedUserID: String? {
        let value = draftUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

#Preview("Needs user ID") {
    FoodLogUserCard(userID: nil, timezone: "America/New_York", onSave: { _ in }, onSettings: {})
        .padding()
        .background(AppPalette.paper)
}

#Preview("Configured user") {
    FoodLogUserCard(userID: "partner-user-123", timezone: "America/New_York", onSave: { _ in }, onSettings: {})
        .padding()
        .background(AppPalette.paper)
}
