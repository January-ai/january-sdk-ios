import Foundation
import JanuaryPartnerSDK
import Observation

/// App-owned user identity persisted across launches and reused by every tab.
///
/// A production app would usually populate this from its authenticated account
/// session instead of asking the user to type an identifier.
@MainActor
@Observable
final class UserSession {
    private enum Key {
        static let endUserID = "demo.endUserID"
        static let timezone = "demo.timezone"
    }

    private let defaults: UserDefaults

    var endUserID: String {
        didSet { defaults.set(endUserID, forKey: Key.endUserID) }
    }

    var timezone: String {
        didSet { defaults.set(timezone, forKey: Key.timezone) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.endUserID = defaults.string(forKey: Key.endUserID) ?? ""
        self.timezone = defaults.string(forKey: Key.timezone) ?? TimeZone.current.identifier
    }

    var partnerUserID: PartnerUserID? {
        AppFormatting.endUserID(endUserID)
    }

    var partnerContext: PartnerUserContext? {
        partnerUserID.map { PartnerUserContext(endUserID: $0, timezone: timezone) }
    }

    func client(for client: JanuaryPartnerClient) -> JanuaryPartnerUserClient? {
        partnerContext.map { client.forUser($0) }
    }

    func clear() {
        endUserID = ""
        timezone = TimeZone.current.identifier
    }
}
