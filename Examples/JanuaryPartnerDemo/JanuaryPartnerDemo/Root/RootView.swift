import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            AppPalette.paper.ignoresSafeArea()

            switch model.state {
            case .loading, .connecting:
                ProgressView("Connecting to January…")
                    .foregroundStyle(AppPalette.body)
            case .ready:
                if let client = model.client {
                    VStack(spacing: 0) {
                        if model.isUsingDevelopmentAuthentication {
                            DevelopmentAuthenticationBanner()
                        }
                        AppTabView(client: client)
                            .environmentObject(model.userSession)
                    }
                }
            case .setupRequired(let detail):
                DemoSetupView(detail: detail)
            case .failed(let message):
                DemoSetupView(detail: message)
            }
        }
        .task {
            await model.bootstrap()
        }
    }
}

private struct DemoSetupView: View {
    let detail: String?

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AppPalette.green)
                            .frame(width: 48, height: 48)
                            .background(AppPalette.targetBand, in: Circle())

                        Text("Welcome to January")
                            .font(AppTypography.screenTitle)
                            .foregroundStyle(AppPalette.ink)

                        Text("To use this demo app, initialize the SDK in code with your token provider or a local development API key.")
                            .font(AppTypography.body)
                            .foregroundStyle(AppPalette.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let detail, !detail.isEmpty {
                        Label(detail, systemImage: "info.circle.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppPalette.goldText)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppPalette.goldBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        SetupOption(
                            number: "1",
                            title: "Use your token provider",
                            badge: "Recommended",
                            message: "Set partnerTokenURL and partnerAppSessionToken in AppConfiguration."
                        )

                        Divider()
                            .overlay(AppPalette.divider)
                            .padding(.vertical, 18)

                        SetupOption(
                            number: "2",
                            title: "Use a development API key",
                            badge: "Debug only",
                            message: "Set developmentAPIKey in AppConfiguration. Never commit or ship it."
                        )
                    }
                    .appCard()

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel("Where to configure")
                            .padding(.horizontal, 0)

                        Text("JanuaryPartnerDemoApp.swift")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppPalette.ink)

                        Text("Edit the AppConfiguration block at the top of the file, then build again.")
                            .font(.system(size: 15))
                            .foregroundStyle(AppPalette.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appCard()
                }
                .frame(maxWidth: 680)
            }
            .padding(.vertical, 40)
        }
        .appBackground()
    }
}

private struct SetupOption: View {
    let number: String
    let title: String
    let badge: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppPalette.greenText)
                .frame(width: 28, height: 28)
                .background(AppPalette.targetBand, in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                Text(badge.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(AppPalette.greenText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppPalette.targetBand, in: Capsule())

                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppPalette.ink)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundStyle(AppPalette.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct DevelopmentAuthenticationBanner: View {
    var body: some View {
        Label(
            "Local testing mode — do not distribute this build with a development API key.",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(AppPalette.goldText)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(AppPalette.goldBackground)
        .accessibilityLabel("Warning: local testing mode. Do not distribute this build with a development API key.")
    }
}

#Preview {
    RootView()
        .environmentObject(AppModel(authentication: .setupRequired()))
}
