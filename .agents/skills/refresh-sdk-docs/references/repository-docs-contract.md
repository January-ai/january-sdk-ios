# January Swift SDK documentation contract

## Source-of-truth order

Use evidence in this order:

1. `Sources/JanuarySDK/` for the public API partners can call.
2. `Package.swift` for package identity, Swift tools version, and supported platforms.
3. `Tests/JanuarySDKTests/` for validation, mapping, defaults, errors, and response behavior.
4. `Examples/JanuaryPartnerDemo/` for the runnable integration path.
5. `Contract/sdk-vocabulary.json` for intended public operation vocabulary.
6. Repository tags and release commits for install revisions, versions, and changelog entries.
7. Existing GitBook Markdown for tone and organization only.

Never let stale documentation override current code and tests. Never present generated transport types from `Sources/JanuaryPartnerTransport/Generated/` as public API.

## Documentation location

- GitBook root: `Documentation/GitBook/`
- GitBook configuration: `Documentation/GitBook/.gitbook.yaml`
- Landing page: `Documentation/GitBook/README.md`
- Navigation: `Documentation/GitBook/SUMMARY.md`
- Git Sync mapping: `main` → `Documentation/GitBook`

All Markdown links must resolve relative to their containing page. Every partner-facing page must appear in `SUMMARY.md` unless it is intentionally excluded and the audit report explains why.

## Source-to-page mapping

| Changed source | Primary documentation |
| --- | --- |
| `Core/JanuaryClient.swift` | Landing page, Quick start, Client and resources |
| `Core/Authentication/` | Authentication and security, Quick start, Troubleshooting |
| `Core/JanuaryError.swift` or transport error mapping | Error handling, Troubleshooting |
| `Core/Identifiers.swift` or shared nutrition models | Client and resources plus every affected guide |
| `Foods/` | Foods guide and affected Quick start examples |
| `Restaurants/` | Restaurants guide |
| `PhotoScanning/` | Photo scanning guide |
| `FoodLogs/` | Food logs guide |
| `Glucose/` | Glucose prediction guide |
| `Package.swift`, package URL, or tags | Landing page, Installation, Changelog when released |
| `Examples/JanuaryPartnerDemo/` | Example app and any matching Getting started flow |
| Public operation additions/removals | Client and resources plus the matching guide |

The mapping identifies pages to inspect, not pages that must always change.

## Partner-visible changes

Update documentation for:

- added, removed, renamed, or relocated public resources and methods;
- request or result type changes;
- new required fields, changed defaults, validation ranges, or optionality;
- authentication or credential-delivery changes;
- changed error categories, codes, retry guidance, or request metadata;
- supported Swift, iOS, or macOS version changes;
- package URL, installation revision, tag, or release changes;
- changed example-app setup or first-use flow;
- behavior partners must adopt to keep an integration working.

Do not update partner documentation for generated transport churn, internal refactors, test-only cleanup, CI changes, or implementation details with no public effect.

## Writing and security boundaries

- Address an application developer integrating the SDK; avoid internal automation and contract terminology.
- Use `JanuaryClient` and its resource properties as the entry point.
- Prefer one focused, compilable Swift sample over exhaustive model dumps.
- State only constraints established by public code, tests, the locked contract, or an observed development response.
- Never include API keys, tokens, customer identifiers, private response payloads, or unsanitized logs.
- Never recommend embedding a long-lived January API key in source code or a distributed application binary.
- Keep pre-release language until a real supported release or tag exists.

## Review triggers

Stop and request product or API-owner input when:

- code and tests disagree about public behavior;
- a server-side constraint is not represented in the SDK or locked contract;
- a release version, support promise, or deprecation date is unknown;
- an example requires credentials or data that cannot be safely represented;
- the requested wording would expose private implementation or security-sensitive details.
