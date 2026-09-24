# User identity and timezone

Every `JanuaryClient` has an end-user ID and a timezone, set when you create it.

## End-user ID

The end-user ID (`endUserID`) is your own stable, opaque ID for the signed-in user, such as `acme-user-8271`. Never use an email address, a name, or other personal data ([terms](https://docs.january.ai/docs/authentication)).

The SDK passes it to your token provider's `fetchClientToken(for:)`, and your backend mints the token for the user its session proves. With a client token, the token decides which user every call acts for: the SDK removes the `January-End-User-ID` header from its calls to January, so a client can't act for anyone but its token's user. With `developmentAPIKey`, the SDK sends the end-user ID in that header on food, water, and weight log calls instead.

Request types such as `SearchFoodsRequest` still take an optional `endUserID`; leave it out. A `JanuaryClient` always uses its own end-user ID and timezone. To act for another user, create another client.

## Timezone

The timezone sets the calendar days for food-log lists and summaries and for water and weight lists. Glucose predictions are sent with it too. Pass the device timezone:

```swift
let client = try JanuaryClient(
    endUserID: endUserID,
    timezone: TimeZone.current,
    clientTokenProvider: tokenProvider
)
```

If you leave `timezone` out, the SDK uses the device timezone at the moment you create the client. Either way, the timezone doesn't follow later changes, so create a new client when the device timezone changes ([Client lifecycle](client-lifecycle.md#when-to-replace-it)).

## Days and dates

Creates take the time an entry happened: `timestampUTC`, `consumedAtUTC`, or `measuredAtUTC`, as an ISO 8601 date-time with any offset. Responses return it in UTC. Lists and summaries take inclusive `yyyy-MM-dd` dates and group entries into calendar days in the client's timezone ([days and timezones](https://docs.january.ai/rest-api/api-overview#days-and-timezones)).

Build those dates in the same timezone:

```swift
let dayFormatter = DateFormatter()
dayFormatter.locale = Locale(identifier: "en_US_POSIX")
dayFormatter.calendar = Calendar(identifier: .gregorian)
dayFormatter.timeZone = TimeZone.current
dayFormatter.dateFormat = "yyyy-MM-dd"

let today = dayFormatter.string(from: Date())
let todaysLogs = try await client.foodLogs.list(start: today, end: today)
```

The 24 L daily water cap is the exception: it counts UTC days ([Log water](../guides/water-and-weight-logs.md#log-water)).

Next: [Food details and portions](food-hydration-and-portions.md).
