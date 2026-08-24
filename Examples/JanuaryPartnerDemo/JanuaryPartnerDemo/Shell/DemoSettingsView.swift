import SwiftUI

struct DemoSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("demo.authenticationMode") private var authenticationMode = "Development API key"
    @AppStorage("demo.endUserID") private var endUserID = ""
    @AppStorage("demo.timezone") private var timezone = TimeZone.current.identifier

    var body: some View {
        NavigationStack {
            DemoScreenShell {
                Form {
                Section("Connection") {
                    Label(authenticationMode, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(DemoPalette.green)
                }

                Section {
                    TextField("End user ID", text: $endUserID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Timezone", selection: $timezone) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { zone in
                            Text(zone.replacingOccurrences(of: "_", with: " ")).tag(zone)
                        }
                    }
                } header: {
                    Text("Request context")
                } footer: {
                    Text("Food Logs requires a stable end user ID. Other requests can include it when available.")
                }

                Section("About") {
                    LabeledContent("App version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Environment", value: "Development")
                }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
