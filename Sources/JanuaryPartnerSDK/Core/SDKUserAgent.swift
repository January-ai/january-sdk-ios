import Foundation

package enum SDKUserAgent {
    package static let sdkVersion = "0.1.0"

    package static var current: String {
        let bundle = Bundle.main
        return make(
            platform: platform,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceFamily: deviceFamily,
            bundleIdentifier: bundle.bundleIdentifier,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            appBuild: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    package static func make(
        platform: String,
        osVersion: String,
        deviceFamily: String,
        bundleIdentifier: String?,
        appVersion: String?,
        appBuild: String?
    ) -> String {
        var parts = [
            "JanuaryPartnerSDK/\(sdkVersion)",
            "Swift/6",
            "Platform/\(token(platform))",
            "OS/\(token(osVersion))",
            "Device/\(token(deviceFamily))",
        ]

        if let identifier = bundleIdentifier, !identifier.isEmpty {
            parts.append("App/\(token(identifier))")
        }
        if let version = appVersion, !version.isEmpty {
            parts.append("AppVersion/\(token(version))")
        }
        if let build = appBuild, !build.isEmpty {
            parts.append("AppBuild/\(token(build))")
        }

        return parts.joined(separator: " ")
    }

    private static var platform: String {
        #if os(iOS)
        "iOS"
        #elseif os(macOS)
        "macOS"
        #elseif os(tvOS)
        "tvOS"
        #elseif os(watchOS)
        "watchOS"
        #elseif os(visionOS)
        "visionOS"
        #else
        "unknown"
        #endif
    }

    private static var deviceFamily: String {
        #if os(iOS)
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineIdentifier
        if model.hasPrefix("iPad") {
            return "iPad"
        }
        if model.hasPrefix("iPhone") {
            return "iPhone"
        }
        return "iOS"
        #elseif os(macOS)
        return "Mac"
        #elseif os(tvOS)
        return "AppleTV"
        #elseif os(watchOS)
        return "AppleWatch"
        #elseif os(visionOS)
        return "AppleVision"
        #else
        return "unknown"
        #endif
    }

    #if os(iOS)
    private static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
    #endif

    /// Restricts values to HTTP product-token-safe characters and prevents an
    /// application bundle value from injecting another header.
    package static func token(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(sanitized.prefix(128))
    }
}
