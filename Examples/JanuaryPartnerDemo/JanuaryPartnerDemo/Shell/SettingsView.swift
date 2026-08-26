import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(UserSession.self) private var userSession
    @AppStorage("demo.authenticationMode") private var authenticationMode = "Development API key"

    var body: some View {
        @Bindable var userSession = userSession

        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                        SectionLabel("Connection")
                        HStack(spacing: 14) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(AppPalette.green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("January Partner SDK")
                                    .font(AppTypography.bodyStrong)
                                Text(authenticationMode)
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.muted)
                            }
                            Spacer(minLength: 0)
                            Text("Connected")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppPalette.greenText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppPalette.targetBand, in: Capsule())
                        }
                        .appCard()

                        SectionLabel("Request context")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("End user ID")
                                .font(AppTypography.bodyStrong)
                            TextField("Partner user identifier", text: $userSession.endUserID)
                                .font(AppTypography.body)
                                .padding(.horizontal, AppSpacing.controlHorizontal)
                                .frame(minHeight: 54)
                                .background(
                                    AppPalette.control,
                                    in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                            Text("Food Logs requires a stable ID. Other requests include it when available.")
                                .font(.footnote)
                                .foregroundStyle(AppPalette.muted)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Timezone")
                                    .font(AppTypography.bodyStrong)
                                Text(userSession.timezone.replacingOccurrences(of: "_", with: " "))
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.muted)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 12)
                            Picker("Timezone", selection: $userSession.timezone) {
                                ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { zone in
                                    Text(zone.replacingOccurrences(of: "_", with: " ")).tag(zone)
                                }
                            }
                            .labelsHidden()
                            .tint(AppPalette.green)
                        }
                        .appCard()

                        SectionLabel("About")
                        VStack(spacing: 0) {
                            LabeledContent("App version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                                .padding(.vertical, AppSpacing.rowVertical)
                            Divider().overlay(AppPalette.divider)
                            LabeledContent("January API", value: "Production")
                                .padding(.vertical, AppSpacing.rowVertical)
                        }
                        .font(AppTypography.body)
                        .appCard()
                    }
                }
                .padding(.vertical, AppSpacing.sheetTop)
            }
            .appBackground()
            .appNavigationBar("Settings") {
                AppNavigationButton(.close, title: "Close settings") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.medium, .large])
    }
}
