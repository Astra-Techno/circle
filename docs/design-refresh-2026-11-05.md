# Social 2.0 implementation — 5 November 2026

Owner approved implementing the entire [design audit](design-audit-2026-11-05.md), then requested one professional font family. This is the durable checklist for that work. Source version **1.0.32+37**, interface marker **Social 2.0**. Implementation is on main only; real deployment and device acceptance remain distinct from source verification.

## Audit coverage

| Audit item | Implementation | Verification/status |
|---|---|---|
| D01 Accessible dock | Measure scaled labels and reflow into centered rows when five columns no longer fit. Keep the existing compact 48px normal row, bounded/symmetric device clearance and logged-in profile photo. | 320px at100/200% label/target/footer checks pass; route review passed; Windows integration pending. |
| D02 Send contrast | Explicit onPrimary icon/foreground for filled chat send; comment send already used the correct semantic foreground. | Group-chat navigation/send foreground regression passes; both themes included in captures. |
| D03 Titles and exits | Privacy has Privacy and blocking title; auth uses Sign in/Sign up. Shared standalone/detail headers use the same back control and allow large titles to wrap/grow. Existing form leave guards and no-history Back fallback retained. | Direct-open event form Back checked at100/200%; header captures pass. |
| D04 Circles duplication | Remove the automatic Pinned copy and misleading pin glyph. Show one searchable nested group tree under Your circles; keep collapse, invitation and membership controls. | One-card regression passes. |
| D05 Inbox discovery | Flat avatar/preview/time/unread rows, local search plus All/Unread/Groups/Archived. Add eligible-person local search. Filtered pagination is explicit and labeled as loaded-page search; no automatic scan of every page. | Archive/unread and second-page search regressions pass; sends/requests/session guards unchanged. |
| D06 Direct group tabs | Tapping or swiping to Chat/Events opens the scoped destination directly. Restore the previous content tab so Back returns to the group. Group Events uses `/groups/g/:id/events` with a permission-gated Create action retaining that exact group. | Exact group destination and Back regression pass; existing large-text journeys updated and pass. |
| D07 Shared forms | Existing56px fields/16px gaps/24px sections retained. Shared compact introductions, clearable search and pinned primary-action form shell for Create group. Label Add photos with measured width for large text; localize event date/time display. | Composer width includes border/padding allowance. Final route review passes. Draft, upload and dirty-exit logic retained. |
| D08 State design | Content-sized panels, meaningful domain/error/access icons, 16px state heading and quieter explanation; retain Retry, Browse Memories and domain actions. | Existing profile-navigation tests pass; all other families inherit shared state sizing. |
| D09 Profiles/settings | Shorter quiet cover fallback, no mountain illustration, Memories ahead of account controls, grouped settings rows and smaller saved-content state. Keep Edit profile and authenticated photo controls. | Profile save/retry, Unicode name and narrow200% flows pass. |
| D10 Event organization | All/Upcoming/Past controls, UTC-instant grouping with nearest upcoming first/recent past first, circle context and localized editor labels. Groups/filters explicitly apply to loaded events; manual more while filtered. Keep RSVP and all access checks. | Past event on later page found without automatic page scan; event query identity resets local paging. |
| D11 Poll hierarchy | Radio affordances for single choice; checkboxes for multiple. Keep results conditional. Refresh/Close under Poll options; closing asks for confirmation. | Single/multiple submissions, cancellation, named/anonymous/hidden results and close regressions pass. |
| D12 Onboarding clarity | Smaller auth branding, meaningful headers, single-line intros, clearer welcome proposition/Create account. Keep explicit country choice and optional location assistance; no fake recovery/OTP. | Auth behavior retained; Windows visuals pending final integration. |
| D13 Notifications | One concise device status, move permission-scope explanation into help, reduce spacing before categories; accurate unavailable-build wording in Account. Preferences/defaults/quiet-hour policy unchanged. | Native push setup/delivery not claimed by UI work; enabled-build capture passes. |
| D14 Typography/icons | Bundle Inter400/500/600 for all type roles; page22/28, sections18/24, body16/24, metadata13/18, buttons15/20 medium. Centralize standard Lucide meanings in CircleIcons and share filter-chip treatment. | Font roles updated in test loader; font/style guard and final analyzer pass. No additional icon library installed. |

All 35 page/state families from the audit are affected through shared typography, headers, state panels and semantic icons, with focused presentation changes above. The existing working privacy, membership, media, notification and performance paths are retained. This does not turn code-only audit gaps into physical-device acceptance.

## Font provenance

Inter comes from Google Fonts `ofl/inter/Inter[opsz,wght].ttf`; source SHA256 `29160a80ff49ddcab2c97711247e08b1fab27a484a329ce8b813d820dc559031`. Static files were instantiated with fontTools4.61.1 at optical size14 and weights400/500/600. The SIL OFL1.1 license is committed, bundled as an asset and registered in Flutter's license registry. No font network request is made at runtime. Older Roboto/Jakarta source assets remain in history/workspace but are not declared as app fonts.

## Boundaries

- No API, SQL migration, backend authorization or notification preference defaults changed. The earlier image/query optimizations remain.
- Complete server-wide chat/contact search and server-side event time filtering require reviewed API support; the implemented controls clearly describe their loaded-page scope.
- Password recovery/OTP, albums, video and other server-unsupported features were not fabricated or enabled.
- Original Android signing key/key.properties are still unavailable here. No replacement key or unsigned APK will be published. Existing verified download links remain.
- Flutter snapshots and mocks do not establish native gesture fidelity, VoiceOver/TalkBack acceptance, actual push delivery or production upload success.

## Integration record

Initial full Linux run:717pass/1skip/30fail. Failures comprised22 intended Windows-golden differences, four stale navigation/copy expectations, two removed profile discovery actions (restored), and two large-text composer overflows (fixed). The final focused route/profile/new-control checks passed18 tests and three existing large-text journeys passed. Subsequent analyzer/format checks pass; final26-check route/control/profile/guard suite, nine scoped-control checks, three existing large-text journeys and eight additional both-theme capture checks pass. Final route matrix5tests/112renders and eight extra capture checks (24renders) also pass. Final Windows integration is pending.

Final Windows baseline review/full CI and iOS delivery are being completed. Do not interpret this record as a release receipt until the delivery results below are updated.

Current render evidence: [Home](design-previews/social-2/photo-home.png), [Chats](design-previews/social-2/chats.png), [Circles](design-previews/social-2/groups.png), [Profile](design-previews/social-2/you.png), [Poll](design-previews/social-2/poll.png), [Login](design-previews/social-2/login.png), [Notifications](design-previews/social-2/notifications.png), [200% navigation](design-previews/social-2/large-text-navigation.png). Page sheets [1](design-previews/social-2/pages-1.png), [2](design-previews/social-2/pages-2.png), [3](design-previews/social-2/pages-3.png), [4](design-previews/social-2/pages-4.png), [5](design-previews/social-2/pages-5.png). All use fictional data; sparse/error fixture states and Linux emoji fallback are not production data findings.
