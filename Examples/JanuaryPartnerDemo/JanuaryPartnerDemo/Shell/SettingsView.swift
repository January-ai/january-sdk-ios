import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @AppStorage("demo.authenticationMode") private var authenticationMode = "Client-token provider"
    @AppStorage("demo.apiOrigin") private var apiOrigin = "Production"
    /// Applied on Return or when Settings closes, so the app does not switch users on every keystroke.
    @State private var draftEndUserID: String?

    var body: some View {
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
                                Text("January SDK")
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
                            TextField("Partner user identifier", text: endUserIDBinding)
                                .font(AppTypography.body)
                                .padding(.horizontal, AppSpacing.controlHorizontal)
                                .frame(minHeight: 54)
                                .background(
                                    AppPalette.control,
                                    in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(applyEndUserID)
                        .accessibilityIdentifier("settings-user-id")
                            Text("Every request is made for this user, and logs are stored under it. A change applies when you press Return or close Settings.")
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
                            LabeledContent("January API", value: apiOrigin)
                                .padding(.vertical, AppSpacing.rowVertical)
                        }
                        .font(AppTypography.body)
                        .appCard()
                    }
                }
                .padding(.vertical, AppSpacing.sheetTop)
            }
            .appBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings-sheet")
            .appNavigationBar("Settings") {
                AppNavigationButton(.close, title: "Close settings") {
                    applyEndUserID()
                    dismiss()
                }
                    .accessibilityIdentifier("settings-close")
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onDisappear(perform: applyEndUserID)
    }

    private var endUserIDBinding: Binding<String> {
        Binding(
            get: { draftEndUserID ?? userSession.endUserID },
            set: { draftEndUserID = $0 }
        )
    }

    private func applyEndUserID() {
        guard let draftEndUserID else { return }
        let value = draftEndUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.draftEndUserID = nil
        if value != userSession.endUserID { userSession.endUserID = value }
    }
}
