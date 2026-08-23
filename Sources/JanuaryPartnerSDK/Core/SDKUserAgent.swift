import Foundation

package enum SDKUserAgent {
    package static let sdkVersion = "0.1.0"

    package static var current: String {
        var parts = [
            "JanuaryPartnerSDK/\(sdkVersion)",
            "Swift/6",
            "Platform/\(token(platform))",
            "OS/\(token(ProcessInfo.processInfo.operatingSystemVersionString))",
            "Device/\(token(deviceFamily))",
        ]

        let bundle = Bundle.main
        if let identifier = bundle.bundleIdentifier, !identifier.isEmpty {
            parts.append("App/\(token(identifier))")
        }
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !version.isEmpty
        {
            parts.append("AppVersion/\(token(version))")
        }
        if let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           !build.isEmpty
        {
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

    private static var machineIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }

    /// Restricts values to HTTP product-token-safe characters and prevents an
    /// application bundle value from injecting another header.
    private static func token(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        return String(sanitized.prefix(128))
    }
}
