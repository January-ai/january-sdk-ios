# Backend token endpoint

Your app must never contain January's long-lived partner key. Put token exchange behind your own authenticated backend.

```text
iOS app ── app session ──▶ your backend ── sk- partner key ──▶ January
      ▲                                │
      └──── { token: "ct-…", expiresIn: 1800 } ───────────────────┘

iOS app ── Authorization: Bearer ct-… ──▶ January Partner API
```

## What your backend owns

Your backend must:

1. Authenticate the caller using your existing app session.
2. Derive the partner-owned user ID on the server; do not trust an arbitrary user ID from the device.
3. Authenticate to January with the server-side partner key.
4. Request a short-lived token scoped to that user.
5. Return the stable token response to the app.

```json
{
  "token": "ct-…",
  "expiresIn": 1800
}
```

The SDK's `JanuaryClientToken` decoder also accepts `expires_in` when your backend relays January's snake-case response unchanged.

## Endpoint location is app configuration

January's SDK cannot know your backend host, path, HTTP method, or session-authentication mechanism. Inject that configuration into your `JanuaryTokenProvider`; the SDK intentionally provides no token-endpoint URL or fallback.

Fail during app configuration when the endpoint is absent. A fallback URL turns a clear startup problem into a confusing runtime or security failure.

## Security rules

* Never return the partner key to the app.
* Never log the partner key or client token.
* Use HTTPS outside local simulator development.
* Authenticate and authorize every token request.
* Keep token responses out of analytics and crash-report breadcrumbs.
* Return a lifetime greater than 60 seconds; the SDK rejects already-expired or nearly expired credentials.

The endpoint implementation is partner-specific. The stable SDK boundary is the response body and the provider protocol, not a hard-coded URL.

Next, implement [Authentication](authentication.md) in the app.
