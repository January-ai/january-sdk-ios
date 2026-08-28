/// Partner-owned identity and locale information reused across January requests.
///
/// Configure this context once when creating ``JanuaryClient``. The client
/// applies it automatically to every resource request and does not persist it.
public struct PartnerUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID
    public var timezone: String?

    public init(endUserID: PartnerUserID, timezone: String? = nil) {
        self.endUserID = endUserID
        self.timezone = timezone
    }
}
