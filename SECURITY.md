# Security policy

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability or include tokens,
credentials, personal data, or exploit details in public discussion.

Contact January through your private partner support channel. Include affected
versions, impact, reproduction steps, and any suggested mitigation. January
will acknowledge the report and coordinate remediation and disclosure through
that private channel.

## Credential handling

January server API keys belong only on an authenticated backend. iOS apps use
short-lived `ct-` client tokens obtained through `JanuaryTokenProvider`. The SDK
keeps client tokens in memory and does not persist them.
