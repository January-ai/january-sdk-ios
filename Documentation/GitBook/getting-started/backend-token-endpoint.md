# Backend token endpoint

The app gets client tokens from an endpoint on your backend. The endpoint is the same for every January SDK: build it from [Your token endpoint](https://docs.january.ai/docs/authentication#your-token-endpoint).

{% hint style="info" %}
No backend yet? Run the [token relay](https://docs.january.ai/docs/authentication#develop-with-the-token-relay) and continue to [Authentication](authentication.md). Come back before launch.
{% endhint %}

## What the iOS SDK reads

Return January's `201` body unchanged. The SDK reads `token` and `expires_in` (it also accepts `expiresIn`) and ignores the other fields.

## Scopes

A `JanuaryClient` uses one token for every call it makes, so mint the token with the scopes of every feature your app uses ([scope table](https://docs.january.ai/rest-api/authentication#client-token-scopes)). A call outside them fails with `403 scope_insufficient`.

## Enable client tokens

Minting fails with `403 forbidden` until **Enable client tokens** is on in the [Developer Dashboard → Client tokens](https://dashboard.january.ai/dashboard/client-tokens).

Next: [Authentication](authentication.md).
