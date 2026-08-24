---
name: refresh-sdk-docs
description: Audit the January Partner Swift SDK against its GitBook Markdown and refresh stale partner-facing documentation. Use when SDK code, public models, endpoints, authentication, errors, package requirements, examples, or releases change; when reviewing whether a code or contract PR needs documentation updates; or when asked to refresh, validate, or synchronize Documentation/GitBook.
---

# Refresh SDK Docs

Keep `Documentation/GitBook` aligned with the public Swift SDK. Audit first, update only externally observable behavior, validate the result, and leave publishing or GitBook synchronization to explicit authorization.

## Load the documentation contract

Read [references/repository-docs-contract.md](references/repository-docs-contract.md) completely before editing. It defines the source-of-truth order, source-to-page mapping, documentation boundaries, and required security language.

## Establish the audit scope

1. Work from the `partner-sdk-ios` repository root.
2. Inspect `git status`, the live remote default branch, its latest commit date, and the current branch or PR.
3. Preserve unrelated and uncommitted work.
4. Use the user-provided base ref when present. Otherwise let the audit script choose the merge base for a feature branch or the most recent GitBook-docs commit on the default branch.
5. Run the audit packet before editing:

```bash
python3 .agents/skills/refresh-sdk-docs/scripts/audit_docs.py --repo-root .
```

Pass `--base-ref <ref>` when the requested comparison point is known.

## Investigate documentation impact

1. Start with changed public files reported by the audit packet.
2. Inspect the complete current declaration or behavior in `Sources/JanuaryPartnerSDK/`; never document a diff in isolation.
3. Use tests to confirm validation, defaults, optionality, error behavior, and response semantics.
4. Use `Examples/JanuaryPartnerDemo` to confirm the runnable integration flow.
5. Use `Package.swift`, repository tags, and release history for installation and compatibility claims.
6. Use the contract vocabulary only to confirm endpoint intent. Never expose generated transport or internal contract-maintenance details to partners.
7. Classify each finding as:
   - **Update required**: a partner-visible capability, signature, constraint, requirement, security rule, or example changed.
   - **No documentation change**: implementation-only refactor with unchanged public behavior.
   - **Needs review**: the code and tests do not establish a safe partner-facing statement.

Do not infer undocumented server behavior or invent examples that the public SDK cannot compile.

## Refresh GitBook Markdown

1. Update the smallest set of pages identified by the repository mapping.
2. Copy established terminology and page structure before adding new sections.
3. Use only public `JanuaryPartnerSDK` types and methods in code samples.
4. Keep examples concise, compilable in context, and based on tested request shapes.
5. Update `SUMMARY.md` whenever pages are added, removed, renamed, or moved.
6. Update the changelog only for an actual partner-facing release or when the user explicitly requests release notes.
7. Retain the credential warning: never embed a long-lived January API key in source code or a distributed application binary.

## Verify the refresh

Run checks only in proportion to the change:

1. Re-run the deterministic documentation audit after Markdown changes:

```bash
python3 .agents/skills/refresh-sdk-docs/scripts/audit_docs.py --repo-root . --check
```

2. Run `swift test --disable-automatic-resolution` when code samples, public signatures, validation rules, or model semantics changed. Skip it for prose-only fixes that cannot affect code accuracy.
3. Preview the primary changed flow in GitBook when access is available. Confirm navigation, headings, code blocks, callouts, and local links render correctly.
4. Do not publish, change site access, connect integrations, commit, push, or trigger Git Sync without explicit authorization.

## Deliver the audit

Report:

- the comparison base and partner-visible code changes reviewed;
- pages updated, or why no documentation change was needed;
- unresolved findings that need product or API-owner input;
- each validation command actually run and its real result;
- whether GitBook is only locally updated, synced, previewed, or published.

The refresh is complete only when every changed partner-visible behavior is documented or explicitly classified, navigation and local links validate, and any unverified claim is called out rather than guessed.
