# Screen audit fixes — Social 2.3

Source version **1.0.35+40** implements the actionable findings from the [full screen audit](full-screen-design-audit-2026-11-06.md). Retains the existing SF/Inter typography, Lucide icons, purple accent, white light-mode pages and shared Memory cards. No backend/API/SQL changes or new dependencies.

## Changes and behavior

| Audit area | Implemented behavior |
|---|---|
| Photo viewer | One immersive close/counter toolbar. React opens the real picker and persists through the workspace repository; Comment opens the Memory and focuses its composer. Unsupported Share removed. Generic photo pagers only show actions supplied by the caller. Reaction selections reject a changed account/API/repository/session. |
| Chat | Removed nested WidgetSpan scaling; body, quote, photos and timestamp compose as ordinary widgets. Requested 100/150/200% text is applied once. Incoming light bubbles use a neutral fill against the white page. |
| Events | Narrow/large-text cards place the date/status above the full-width title/metadata. Cover labels are bounded. No text-scale cap. |
| Circle hierarchy | Indentation responds to the actual list pane, including tablet split views. Decorative covers yield space at narrow/large text; names can wrap. Collapse controls, membership scope and hierarchy remain. |
| Invitations | Accepted tab reflects the actual accepted received invitations. Invite-link entry remains available with populated, empty and error lists. No fictitious outgoing history added. |
| Vocabulary | Circle, InCircle and Memory creation labels distinguish the actions. Circle's plus action is labelled Memory; child creation is Create InCircle. Settings/privacy copy follows the same terms. |
| Forms | Shared progressive counters show while editing/near limits; maxLength enforcement retained. Removed duplicate creation/edit intros. Country code/mobile fields stack when needed. Optional location assistance sits behind Country code help. Planned OTP/recovery text removed without inventing a recovery feature. |
| Profiles | Empty-cover own profiles use a compact avatar/add-cover row. Other-member covers only reserve space when loaded. Settings live in the existing gear/Account destination. Private details expand on demand; duplicated Recent Memories empty heading removed. Real covers and shared cards remain. |
| Devices | Current-device badge, last-active summary and expandable app/network/location details; existing location confirmation, removal and session logout behavior retained. |
| Notifications | Account master switch with permission explanation and explicit Connect this phone when needed; category preferences, saved opt-outs, connection help and quiet hours retained. |
| Unavailable features | Albums/Activity remain capability-gated; no fictional live feature or new data contract introduced. Search and profile history still describe their loaded-page limitations honestly. |

## Verification

- Final Dart format: 250 files checked, zero changes. Flutter analyzer: no issues.
- New targeted regressions: **11 passed**, including exact paragraph/ancestor scaling at 100/150/200%, working photo reactions/comment focus, rejecting a changed-session reaction, full-width Event title at 320px/200%, and populated Accepted/link-entry behavior.
- Final focused flows: **49 passed** (audit/session regressions, settings navigation/capabilities, chrome/keyboard, scoped surfaces, country selection and notification choices).
- Remaining auth/Circle journeys: **40 passed**, excluding Windows golden comparisons.
- Final main matrix **5 passed**, additional states **4 passed**, producing **236 renders / 59 variants** across normal light/dark, 320px/200% dark and 900px/200% light. All contact sheets and representative full-resolution screenshots reviewed. Extended fixtures assert that the direct request state actually exposes Accept request.
- Initial broad local run: **743 passed, one skipped, 17 failures**. Thirteen were Windows-image comparisons; four were a capture-fixture type mismatch and stale expectations for moved settings/removed OTP copy. Those were corrected and covered in the passing reruns above. Nine additional dedicated Windows goldens were excluded locally. This is not an all-green full-suite claim; Windows full verification and baseline review are recorded below when complete.
- No backend files changed; backend suites were not rerun.

## Screenshot evidence

Actual Flutter widgets with fictional data. Desktop Inter rendering is not native iPhone SF validation. Fixtures intentionally include error states; they do not establish production outages. Notifications are an isolated component capture, not a real OS permission test. Device version1.0.12(13) is historical fictional session data, not the new app version.

| Matrix | Light | Dark | Narrow / 200% | Tablet / 200% |
|---|---|---|---|---|
| Main routes | [View](design-previews/social-2.3/main-393-1.0-light.jpg) | [View](design-previews/social-2.3/main-393-1.0-dark.jpg) | [View](design-previews/social-2.3/main-320-2.0-dark.jpg) | [View](design-previews/social-2.3/main-900-2.0-light.jpg) |
| Additional states | [View](design-previews/social-2.3/extra-393-1.0-light.jpg) | [View](design-previews/social-2.3/extra-393-1.0-dark.jpg) | [View](design-previews/social-2.3/extra-320-2.0-dark.jpg) | [View](design-previews/social-2.3/extra-900-2.0-light.jpg) |

[Full-resolution files and hashes](design-previews/social-2.3/manifest.json). The App Editor plugin guidance informed implementation; Stitch remains unauthenticated/blocked and no connected Stitch design output is claimed.

## Delivery

Windows full refresh run [42188148877](https://github.com/Astra-Techno/circle/actions/runs/42188148877) passed **773 tests / one skipped**, format and analyzer clean. All22 generated baselines reviewed:7 expected changes (welcome/login/register/light+dark, Circle detail/create, Profile),15 unchanged including every Home baseline. [Review sheet](design-previews/social-2.3/windows-baseline-review.jpg). The connected GitHub plugin supplied the artifact/logs when shell access to the artifact host was restricted. Final normal comparison follows the baseline publication commit.

Signed Android1.0.35(40) built and verified; [APK verification](mobile-release-1.0.35-android.md). Signed iOS run [42188155025](https://github.com/Astra-Techno/circle/actions/runs/42188155025) is compiling after passing its platform-independent guards; upload is not yet confirmed. Runtime source changes do not update already installed apps. Physical iPhone/Android appearance, picking, actual push and Apple processing/tester availability remain separate acceptance checks.
