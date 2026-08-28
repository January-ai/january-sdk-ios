import Foundation

/// Optional partner-owned identity and locale information reused across January requests.
///
/// Configure this context once when creating ``JanuaryClient``. The client
/// applies it automatically to every resource request and does not persist it.
/// An omitted timezone resolves to `TimeZone.current.identifier`.
public struct PartnerUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID?
    public var timezone: TimeZone

    public init(endUserID: PartnerUserID? = nil, timezone: TimeZone? = nil) {
        self.endUserID = endUserID
        self.timezone = timezone ?? .current
    }
}
