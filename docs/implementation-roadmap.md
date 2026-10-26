# Implementation roadmap — 26 October 2026

Current execution priorities and next-release scope are in [pending-work.md](pending-work.md). This document retains the original 24-finding audit and historical verification. Its earlier passing counts do not establish that subsequent Firebase changes are regression-free.

This tracks all 24 findings in the deep app review of `c59aaf3` (Android beta 1.0.4+5). It is a plan and acceptance checklist, not a completion claim. Implementation and validation results belong in the release record. Parallel agents implemented and verified the current wave below. These source/test results do not establish deployment, installation or native-device validation.

## Historical delivery wave — builds 5–7

Prioritize the complete loop: join an exact private group, share a photo Memory, find it again, and recover from ordinary interruptions. Preserve audience checks, explicit joining consent and the existing name editor. Shared design tokens remain the basis for visual depth.

ZIP, GD and mbstring were confirmed in the live web runtime during the completed delivery wave. Photo checks passed 25/25 and query checks 45/45 with fixture cleanup. Builds5–7 were deployed and their hosted artifacts verified. Later remote commits introduced signing/publication and capability/Firebase regressions; see the current backlog and project state before treating this history as current readiness.

| # | Finding | State / next delivery | Acceptance evidence required |
|---|---|---|---|
| 1 | Live photo processing | Validated live: 25/25 media checks passed with cleanup | Fictional-data ticket, upload, decoded/re-encoded private media, signed retrieval, Memory attachment and cleanup; retain rejection of invalid images and inaccessible groups. |
| 2 | Reliable APK delivery and version identity | Previously verified; later signing/metadata regression requires B5 | Deployment succeeds; public immutable APK size/hash matches release metadata; installed build is identifiable. Retain signing key for beta updates; establish backed-up production signing separately. |
| 3 | Group timeline false empty | Implemented; scoped Memory regression suite: 27 passed | An older group Memory appears on direct opening despite being absent from Home's first page; page loading, error/retry and access loss tested. |
| 4 | Saved timeline false empty | Implemented; covered by 27 scoped Memory regression checks | Older saved items appear after cold start without browsing Home; pagination, unsave and exact-group visibility tested. |
| 5 | Search of older content | Implemented; 27 scoped client checks; backend 129 tests / 1,955 assertions and PHPStan passed | Older accessible text/place matches appear without preloading; combined filters/cursors, literal wildcard input, Unicode and inaccessible groups tested. Live help describes supported content only. |
| 6 | Native invitation entry | Implemented entry/configuration; 7 focused invite tests passed; native verification pending | Valid invite survives signed-out login/registration and reaches preview; malformed/untrusted links rejected; join/approval still explicit. Verified HTTPS links, browser fallback and native share sheet require their own validation. |
| 7 | Account lifecycle | Contract/design phase | Review recovery, password change, number verification/change, deletion and export; generic public failures and revocable sessions; no support-side password reset bypass. Test client/server flows before exposing controls. |
| 8 | Lost drafts and interrupted uploads | Encrypted scoped text drafts implemented; 21 persistence/settings checks passed including Resume/Discard and successful-share cleanup; durable uploads planned | Resume/discard after restart; no cross-account/group leakage; logout clears scope. Text/year/place recovery does not imply photo bytes or OS background upload persistence. Test interrupted uploads separately. |
| 9 | Cold-start offline content | Planned storage design | Previously opened group readable offline after restart; private account-scoped cache, expiry and access/session revocation policy; pending versus rejected actions clearly distinguished. |
| 10 | Reports/privacy/coordination | Contract phase | Reports reach authorized admins; blocking/privacy effects enforced server-side; preferences and direct-invite consent persist. Existing member ban/removal remains distinct from reporting. |
| 11 | Unavailable primary destinations | Previously implemented; later capability-flag regression requires B2 | Live navigation emphasizes Home/Groups/You; preview retains future destinations; direct routes remain accurately gated. Group future tabs need equivalent review. |
| 12 | Home space and group selection | Compact introduction delivered; searchable full-path selector pending | First Memory visible sooner; preserve complete original artwork; searchable picker shows full paths and distinguishes same-name subgroups. Verify many groups and large text. |
| 13 | Large group header | Planned UI pass | Compact identity/audience/ancestry; single management entry; existing content reachable on small phones without a large introductory block. |
| 14 | Invitations bury groups | Expandable summary delivered and tested | Compact expandable invitation summary leaves groups visible early; explicit Accept/Decline remains reachable and accessible. |
| 15 | Floating-action overlap | Large-text fixed create footer delivered; native validation pending | Last list row/action reachable; safe areas, keyboard, narrow screen and largest supported text size checked on Android. |
| 16 | Appearance resets | Implemented; included in 21 persistence/settings checks | Intentional choice survives restart; Light remains first-run default; delayed reads cannot overwrite a newer choice; unavailable storage handled. |
| 17 | Generic recovery errors | Timeline retry and draft restoration implemented/tested; broader pass planned | Distinguish offline, session expiry, lost membership, unavailable processor and upload interruption; preserve input and provide appropriate next action. |
| 18 | Limited profile identity | Name editor delivered; expanded profile work remains local/uncommitted, B4 | Reviewed photo/bio upload and visibility rules; successful editing/retry plus private media access tests. Do not label name editing missing. |
| 19 | Unreachable legal/privacy copy | Factual audience copy implemented; approved legal documents remain separate | Accurate nonagreement copy replaces an unsupported acknowledgement; factual audience explanation replaces absolute privacy promises. Owner-approved document content needed before presenting a legal agreement. |
| 20 | Localization/accessibility | Native and translation work planned | Licensed Tamil-capable fallback; agreed translated strings; mixed scripts/RTL/long names, TalkBack, focus, contrast and reduced motion verified on devices. |
| 21 | Eager startup/member limit | Performance/data-loading design planned | Summaries before selected-group details; paginated members with explicit partial/loading states; no silent 2,000-member completeness claim; measured request counts and first-content latency. |
| 22 | Delete/Undo process death | Reproduction/behavior decision pending | Kill during Undo window; documented durable pending-operation or rollback behavior; no unexplained resurrection or duplicate deletion. |
| 23 | Soft 3D performance | Device profiling pending | Frame timings and scrolling measured with many photos/avatars on representative lower-end Android; lighter list surfaces if needed. Static renders do not establish smoothness. |
| 24 | Visual and release validation | Functional suite: 500 passed, 1 opt-in live smoke skipped; 13 golden comparisons pending Windows review; analyzer and format clean | Format/analyzer/unit/widget/backend checks recorded; Windows golden differences reviewed and approved; native link entry, recreation, permissions, interruptions and update install tested. Never claim mock/widget checks are physical-device validation. |

## Follow-on feature families

These are supported by preview UI, not established live services. Each increment needs reviewed OpenAPI behavior, persistence, authorization and failure tests, followed by client integration and fictional-data live checks. ADR 0006 requires review by both backend and mobile tracks for contract changes.

| Increment | Decisions and exit criteria |
|---|---|
| Recovery and account controls | ADR 0005 requires explicit secure recovery/number-change design. Choose ownership-verification channel/provider and abuse controls; define session revocation, deletion/export and retention. Never invent SMS delivery or a reset bypass. |
| Safety and notification foundation | Define reports, admin review/actions, privacy/blocking, device registration and persistent quiet-hours/mutes. Push requires project credentials and delivery infrastructure; never embed service credentials in APKs. |
| Direct invitations and listed-subgroup joining | Consent inbox and reviewed join/request endpoints; parent membership checked on request and approval; no inherited subgroup content access. |
| Chat | Delivery/idempotency, message requests, read states, privacy and membership synchronization. Removed members retain only the documented frozen history; test every permission transition. Provider/transport and encryption scope must be explicit. |
| Events and RSVPs | Time-zone-aware scheduling, guest counts, capacity and cancellation; reminders require a functioning scheduler/delivery path. |
| Polls | Named/anonymous voting, result visibility, changes/closure and permission checks across each supported container. |
| Albums | Private media lifecycle, covers/captions and event integration; no public storage URLs. |
| Comment edit/delete and profile expansion | Explicit authorship/admin permissions, edit/delete semantics and profile audience; do not expose preview controls as working APIs. |

## Verification and release discipline

The counts below describe the earlier delivery wave. The latest reviewed runtime commit `8c1f677` has known failing server-flow/static checks recorded in PROJECT_STATE.md and must be reverified after fixes.

Run backend tests against `circle_test` only. Coordinate agents before shared suites or release packaging; focused tests may run independently. Contract review and regression coverage must precede release claims. Record actual pass/fail/skip counts and unresolved golden differences; do not replace Windows-approved baselines with Linux output.

Current verification: the full functional suite reports 500 passed and one opt-in live smoke skipped; 13 golden comparisons remain for Windows review. Flutter analyzer and format checks are clean. Focused scoped-Memory coverage reports 27 passed, persistence/settings coverage reports 21 passed, and invitation coverage reports seven passed. Backend reports 129 tests / 1,955 assertions passed and PHPStan clean. These suite counts describe different test selections and must not be added together as unique coverage. Physical-device checks and the larger service families remain pending.

Build with the existing beta signing key and production API configuration, publish an immutable versioned APK plus verified metadata, then compare the hosted bytes. A successful source push alone does not prove the site was deployed or the phone updated. New deployment-script source requires one manual hosting replacement if the installed script does not update itself.

## Delivery verification

Android beta 1.0.5+6 and backend changes were committed and pushed in c0b4cd3, then deployed successfully using ZIP support. The live runtime confirms ZIP, GD and mbstring loaded. Both hosted APK paths matched the committed 63,002,644-byte artifact and SHA-256; release metadata matched. Post-deployment Memory query regression passed 45/45 with fixture cleanup. See [release record](mobile-release-1.0.5.md). These checks close this delivery wave; feature families and native/visual acceptance work marked pending above remain pending.

## Visual refinement follow-up

Android beta 1.0.6+7 implements a compact Home brand introduction, richer shared indigo accents, softer depth, a rounded navigation dock, expandable invitation summaries and root-group cards. At large text sizes, decorative headers become compact and create actions move into a fixed footer above navigation. Functional regression checks passed 500 tests with one opt-in skip, and seven signed-in layout renders passed; 13 Windows golden comparisons and physical-device validation remain pending. See [release record](mobile-release-1.0.6.md) and [visual review](design-previews/1.0.6/README.md). No additional backend feature families were introduced.
