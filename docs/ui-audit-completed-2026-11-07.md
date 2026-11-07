# UI audit corrections — 7 November 2026

Implements the source-level findings from [the audit](ui-audit-2026-11-07.md), retaining the approved Home header, icon-only navigation and shared Memories/Poll/Event cards. Interface marker Social 2.5; candidate version 1.0.37+43. Client-only: no backend, SQL, capabilities or authorization changes.

| Audit area | Implemented correction |
|---|---|
| Controls | Dedicated interactive outlines separated from decorative hairlines; enabled radio, checkbox and field boundaries checked at ≥3:1 on page, recessed and ballot surfaces in both themes. |
| Nested pages | Opaque route/ReadingPane surfaces and individually clipped Circle shortcut Material. A pixel regression checks that Circle tile ink cannot appear beneath its Events child after navigation settles; Back remains functional. |
| Events | Shared responsive date/title/menu identity; RSVP labels retain full text scaling and wrap. At large text, actions scroll after details instead of consuming the viewport. Duplicate Edit event heading removed. |
| Invitations | Correct ID-route title; full-width wrapping Circle identity, inviter and time with Accept/Decline preserved. Retry action belongs to the error state. |
| Forms | Shared persistent wrapping labels on 31 text/select inputs across auth, Circle creation/settings, Poll creation, Event creation/edit/RSVP, profile and password. Preserve validators, focus, autofill, counters, values and existing submission services. Neutral base fields; purposeful date/time tint retained. |
| Headers/type | Flat default header actions,48px targets, more accurate large-text title height, no empty introduction paragraphs. Existing native Apple/Inter font policy and system Bold Text preserved. |
| Chat | More readable message width at large text; full wrapping conversation identity; concise search labels with truthful search-scope helper text. Privacy errors scroll and use consistent recovery. |
| Profiles | Aligned member identity with personal-profile sizing, concise Message action with full semantic recipient, known viewer-name fallback in comment avatars. Edit Profile drops a repeated section title. |
| States/settings | Consistent error/action grouping in invitations, devices, reports and messaging privacy; readable session-card hierarchy; shared search empty state. Already-loaded device content remains available on refresh failure. |
| Unsupported pages | Albums deep links show an honest unavailable state and working way back; capability gates remain closed. |
| Welcome | One illustration, short promise, account/login actions; removed decorative quality/member-count badges and unsupported age-range claims. Enlarged the small privacy note after the contrast guideline exposed weak rendered legibility. |
| Navigation/cards | Approved dock, Home/header/card geometry, real actions/counts/privacy and private image behavior retained. No new icon family or font download. |

## Verification

- Initial focused suite:56 passing checks, including four-layout route renders, Poll/Event cards, design guard, form layout, account security and profile photos.
- Added regressions for control contrast, settled child-page pixels/back navigation, persistent-label semantics at200%, and invitation route title.
- Updated two existing UI flow tests to locate inputs below persistent labels; their keyboard/submission expectations remain intact.
- Local broad run:805 passed/1skipped/2 failures captured before the final welcome/field-finder corrections. Final affected suites:23 passed, including welcome accessibility, keyboard reachability and the four new regressions. Analyzer clean; Dart format257files clean; font identity check passed. Windows full-suite and baseline review pending. Windows baselines must not be generated on Linux.

## Limits

Flutter renders and fictional service fixtures do not verify an installed iPhone/Android build, screen readers, real-network images, production latency, native photo/contact sheets or push delivery. A capability-disabled screenshot is not evidence of a live outage. Publishing source is distinct from deploying the backend or installing a new client. Release receipts, if produced, are recorded separately.
