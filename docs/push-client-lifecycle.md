# Client push foundation N1c1 — 27 October 2026

This source checkpoint implements locally scoped reception and SDK lifecycle. It does not enable push, add an opt-in screen, render notifications or implement tap navigation. The live downloadable APK remains 1.0.7+8; no build or deployment is part of this checkpoint.

## Session and SDK ownership

Dart application startup no longer calls Firebase initialization. The lazy Android-only gateway is constructed without accessing Firebase/plugin state. Android metadata disables automatic token initialization, and explicit activation keeps auto-init false rather than persisting true across restarts. Token acquisition is explicit. Native behavior with auto-init disabled still requires device verification; SDK fake tests are not that evidence.

One foreground coordinator serializes SDK initialization, permission checks, registration, token changes and cleanup. Repeated starts reuse initialized SDK state and listeners, recheck permission/current token, and avoid duplicate registration when unchanged. Only an explained future user action may request permission; passive starts never prompt. There is currently no start caller in the app, and CIRCLE_PUSH_ENABLED defaults false.

Generation checks invalidate old callbacks immediately. Account/server changes, login attempts, logout and session expiry stop push without awaiting SDK/network work. Authentication uses an independent core lifecycle signal; it does not depend on the notification provider. Registration from an old scope cannot finish after the next scope's serialized registration. Best-effort cleanup disables SDK auto-init/deletes the native token and unregisters known/ambiguous token attempts only while the old authenticated API scope still matches. In-memory attempted tokens are bounded to eight. Server logout remains independently responsible for revocation; offline provider/server cleanup cannot be guaranteed.

SDK, permission, token-storage and registration failures do not throw into authentication. Token refresh failures mark registration unhealthy so an explicit later start can retry. Removed listeners and stale SDK completions cannot emit accepted events for the next account.

## Envelope checks and persistent acceptance history

The parser follows OpenAPI 0.3.5: only the supported nine string fields and Memory/comment/reply types are accepted. IDs are canonical positive unsigned-64-bit values; comment references must match the event kind. It checks expiry, bounds lifetime to the worker's 24-hour window plus five minutes of clock tolerance, and matches the configured canonical HTTPS API URL, current account and SHA-256 login-session scope. Unknown routes, private-text additions, foreign URLs/scopes, expired events and malformed payloads are rejected.

Session scope comes from the stored access-token sid, not a token fingerprint that changes on refresh. Decoding JWT claims locally does not validate their signature or authorize group content. The future renderer must fetch through the configured authenticated API and recheck active scope after asynchronous work. It must never choose a credential destination from incoming data.

One encrypted LocalSettingsStore history contains at most 512 unexpired claims across all scopes. Keys include the server/account/session digest, event id and intended action. Concurrent claims serialize, history survives app/coordinator restart, and ordinary transport stops preserve it. Expired claims prune on the next claim; capacity/corrupt-storage/write failures fail closed rather than evicting live duplicate protection. Opening is separate from display acceptance, so a legitimate tap is not discarded after foreground receipt. Scope-specific deletion is reserved for explicit account-data cleanup.

Accepted events are local metadata handoffs, not evidence of display, delivery or content authorization. Durable/idempotent presentation handoff and failure handling must be completed with the renderer before enablement. The current ledger serializes one foreground coordinator; it is not a cross-isolate atomic notification store. The background callback intentionally does not present messages until its independent scope/dedup/authorization path is implemented.

## Validation and remaining work

Focused runs passed four envelope/history tests, eight lifecycle tests and 11 server-mode regressions. These cover scope/type/expiry rejection, refresh-stable sid hashing, persistence, concurrent dedup, per-action separation, storage/capacity failure, permission denial/revocation, unsupported platforms, SDK errors, stopped initialization, in-flight account switching, token rotation, same-scope restart and initialized-provider login/logout without dependency cycles.

Scoped static review found persistent auto-init and premature history deletion; both were fixed and rechecked with no remaining blocker in this scope. Android XML parses with exactly one auto-init=false declaration. Flutter format/analyze are clean. Full Flutter run: 525 passed, one opt-in smoke skipped, and 13 failed golden comparisons matching the previously recorded Windows-baseline cases. Baselines are unchanged. Backend and API contracts are unchanged from the verified 159-test worker checkpoint and were not rerun for this client-only batch. Windows golden approval and real SDK/device behavior remain separate.

Next N1c2: contextual server preference/permission UI, trusted authorized content lookup, durable presentation handoff, foreground notifications and validated internal tap handling. Background/terminated reception, offline logout, real Android update/install behavior and device delivery must be verified before switching on client/backend capabilities. Hosting credentials/scheduler, reaction/group hooks and later feature families remain in docs/pending-work.md. No iOS delivery or working end-to-end push is claimed.
