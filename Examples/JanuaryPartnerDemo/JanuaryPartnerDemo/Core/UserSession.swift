import Combine
import Foundation
import January

/// App-owned user identity persisted across launches and reused by every tab.
///
/// A production app would usually populate this from its authenticated account
/// session instead of asking the user to type an identifier.
@MainActor
final class UserSession: ObservableObject {
    private enum Key {
        static let endUserID = "demo.endUserID"
        static let timezone = "demo.timezone"
    }

    private let defaults: UserDefaults

    @Published var endUserID: String {
        didSet { defaults.set(endUserID, forKey: Key.endUserID) }
    }

    @Published var timezone: String {
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
        partnerUserID.map {
            PartnerUserContext(
                endUserID: $0,
                timezone: TimeZone(identifier: timezone) ?? .current
            )
        }
    }

    func clear() {
        endUserID = ""
        timezone = TimeZone.current.identifier
    }
}
