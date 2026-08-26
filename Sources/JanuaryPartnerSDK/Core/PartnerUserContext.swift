/// Partner-owned identity and locale information reused across January requests.
///
/// The SDK does not persist this value. Keep it in your app's authenticated
/// session and create a scoped client when the active user changes.
public struct PartnerUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID
    public var timezone: String?

    public init(endUserID: PartnerUserID, timezone: String? = nil) {
        self.endUserID = endUserID
        self.timezone = timezone
    }
}
