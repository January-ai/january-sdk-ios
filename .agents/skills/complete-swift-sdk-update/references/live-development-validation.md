# Live development validation

Use the public `JanuaryPartnerSDK` API for all live calls. Do not use `curl`, direct `URLSession` requests, generated transport calls, or copied JSON as a substitute.

## Credentials

- Use the gitignored repository `.env` file consumed by `scripts/run-full-smoke.sh`.
- Required development variables are `JANUARY_DEV_API_KEY` and `JANUARY_END_USER_ID`.
- Never print, paste, commit, hardcode, or include credentials in logs, diffs, fixtures, screenshots, PR text, or reports.
- If credentials are unavailable, finish deterministic verification and report live validation as blocked. Do not invent or recover credentials from history.
- Run production only after explicit authorization. Development is the default.

## Full development run

Run from the repository root:

```bash
./scripts/run-full-smoke.sh development
```

The program must execute through `JanuaryPartnerClient` and fail with a nonzero exit when an operation or assertion fails. A skipped run is not a pass.

## Coverage requirements

- Keep the full smoke program covering the complete public operation set, including every newly added operation.
- Validate meaningful response data, not only a successful HTTP status.
- For photo scanning, exercise both the governed remote image URL and the committed base64 fixture.
- For create/update/delete flows, use a unique test name and guarantee best-effort cleanup when a later assertion fails.
- Reuse returned IDs and server data rather than inventing dependencies between operations.
- Keep test inputs stable and clearly identifiable as SDK smoke data.
- Do not expose raw server payloads if they contain identifiers or sensitive data; report operation name, pass/fail status, and safe counts or categories.

## Changed endpoints

When a contract update adds or changes an operation:

1. Add it to `JanuaryPartnerFullSmoke` before running live validation.
2. Exercise every supported request form affected by the change.
3. Assert the fields the public façade promises to consumers.
4. Confirm headers and request mapping with local transport tests; use live tests to validate server interoperability.
5. If the server behavior differs from the locked contract, stop and report the exact mismatch. Do not silently adapt the SDK to undocumented behavior.

## Reporting

Report:

- Environment: development or explicitly authorized production.
- Each operation executed through the public SDK.
- Safe result details such as item or detection counts.
- Cleanup outcome for any created data.
- Exact failures or operations not executed.

Never describe the SDK as live-validated when the smoke program skipped, failed, or omitted a changed operation.
