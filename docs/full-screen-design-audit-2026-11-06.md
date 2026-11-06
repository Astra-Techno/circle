# Circle screen design audit — 6 November 2026

Audit only: no app UI, backend, signing or release changes. Source reviewed: `3a26a30`; runtime remains 1.0.34+39 / Social 2.2.

## Verdict

White light-mode canvases, shared Memory cards and the existing SF/Inter typography now provide a coherent base. Circle still feels less finished than the reference social apps because some controls do not work, text scaling breaks the intended hierarchy, several labels misdescribe their destinations, and forms/settings expose too much detail at once. Another font or icon-library replacement would not address those problems.

Keep native SF on Apple, corrected Inter elsewhere, Lucide icons, the purple accent, white light-mode pages and the shared Home/Circle/Profile cards. Improve interaction quality and hierarchy before adding decorative effects or features.

## Evidence and limits

Applied the installed App Audit plugin framework to native Flutter screenshots and source. The web page checker is inappropriate for this native app; no web scores were generated. Stitch has no registered tools or configured key and its endpoint is blocked. Maestro has no attached device. No Stitch-generated design or physical-device inspection is claimed.

Captured **57 screen/state variants × four configurations = 228 PNGs**: 393px normal light/dark, 320px dark at 200% text, and 900px light at 200% text. Reviewed every contact sheet and representative full-resolution frames. Actual Flutter widgets use fictional populated/empty/error fixtures, not production accounts. Desktop renders use Inter; native iPhone SF appearance, keyboard behavior, OS permissions, screen-reader experience and every role/dialog/loading state remain unverified.

The main matrix passed five checks; extended states passed four; diagnostic text measurements passed two. These 11 passing checks establish captures without framework exceptions, **not visual acceptance or end-to-end functional verification**. Temporary capture scripts were removed after recording evidence.

[Evidence manifest and hashes](design-previews/audit-2026-11-06/manifest.json)

| Matrix | Normal light | Normal dark | Narrow / 200% | Tablet / 200% |
|---|---|---|---|---|
| Main 28 routes | [View](design-previews/audit-2026-11-06/main-393-1.0-light.jpg) | [View](design-previews/audit-2026-11-06/main-393-1.0-dark.jpg) | [View](design-previews/audit-2026-11-06/main-320-2.0-dark.jpg) | [View](design-previews/audit-2026-11-06/main-900-2.0-light.jpg) |
| Additional 29 states | [View](design-previews/audit-2026-11-06/extra-393-1.0-light.jpg) | [View](design-previews/audit-2026-11-06/extra-393-1.0-dark.jpg) | [View](design-previews/audit-2026-11-06/extra-320-2.0-dark.jpg) | [View](design-previews/audit-2026-11-06/extra-900-2.0-light.jpg) |

## Top five changes

Effort estimates are implementation estimates, not delivery promises.

| Priority | Finding and proposed change | Impact | Effort |
|---|---|---|---|
| 1 | Photo viewer React/Comment/Share are visual rows with no handlers. Wire supported Memory actions and remove unsupported Share; consolidate duplicate outer/inner toolbars. | Restores truthful controls in a central content flow. | Medium |
| 2 | Chat applies text scaling twice. Apply it once; add a soft neutral incoming bubble on the white canvas. | Restores accessible reading and recognizable conversation structure. | Medium |
| 3 | Events and deeply nested Circles squeeze names at narrow widths/large text. Reflow event metadata and reduce responsive indentation. | Makes essential content readable without disabling text scaling. | Medium |
| 4 | Invitations “Sent” actually means accepted received invitations; paste-link action disappears from populated inbox. Rename Accepted, keep link entry visible and standardize Circle/InCircle/Memory labels. | Removes misleading navigation and dead ends. | Small–medium |
| 5 | Simplify form, profile and settings hierarchy: one heading, relevant helper text, compact empty-cover profiles, expandable technical device details. | Gives the app clearer, calmer screens. | Medium–large across all pages |

### Confirmed source evidence

- `mobile/lib/features/memories/presentation/memory_photos.dart`: `_PhotoAction` is only an icon/text Row; no callback or interactive semantics. Supported React/Comment should reuse existing Memory operations. Do not expose Share until its behavior and privacy requirements are implemented.
- `mobile/lib/features/chat/presentation/live_chat_design.dart`: `ChatMessageBubble` embeds already scaled child text in a `WidgetSpan` inside `Text.rich`. Measurements at 393px: requested 100% → font16 × paragraph1 × ancestor1; requested 200% → font16 × paragraph2 × ancestor2. Effective glyph sizing reaches approximately 400%. Fix composition, not the user's text setting; check incoming/outgoing, replies, queued messages and photo captions at 100/150/200%.
- `mobile/lib/core/design.dart`: incoming chat bubble and wallpaper are both white in light mode, removing the visible bubble boundary.
- `mobile/lib/features/events/presentation/live_events.dart`: date block, gaps and trailing badge share one Row with the title. At 320px/200%, the title and metadata wrap into tiny fragments even though no overflow exception occurs. Move secondary information beneath the title when needed.
- `mobile/lib/features/groups/presentation/circle_groups.dart`: nested indentation, fixed cover/trailing controls and one-line ellipsis consume the name area. Use responsive indentation and two-line names while retaining hierarchy and permissions.
- `contact_invitation_inbox.dart`: the “Sent” filter selects `status == accepted` from received `/me/group-invitations`. Rename it Accepted; an outgoing history would require a separate supported data contract.

## Page-by-page recommendations

| Screen family and inspected states | Assessment and recommendation |
|---|---|
| Welcome, sign-in, registration | Too much instruction competes with the primary action. Keep one benefit, a short privacy statement and clear account actions. Reflow country code/mobile fields at large text. Move optional location assistance below the main task. Remove roadmap copy about planned OTP/recovery; do not invent a recovery button without backend support. |
| Home and Memory detail/comments | Shared card structure is now consistent. Preserve it. Give author, content, metadata and actions clearer relative emphasis; keep caption text regular and metadata quieter. Preserve pagination and private image behavior. |
| Photos gallery and full-screen viewer | Gallery is coherent; viewer has duplicate toolbars and inert action labels. Use one immersive toolbar, a readable caption and only supported controls. |
| Circles list/search/tree | Hierarchy is useful but deep rows truncate names severely. Reduce indentation at narrow widths, allow wrapping and show parent context where needed. |
| Circle detail, pending membership | Existing quick-action icons and shared feed should remain. Clarify the plus action as Memory/Post, since it opens the Memory composer. Keep Members/InCircles discoverable without restoring the removed tab strip or duplicate share row. |
| Members, InCircles, child creation | Match parent/child terminology and clarify visibility. Forms currently mix Circle, group and subgroup. Preserve scoped membership and ownership behavior. |
| Circle settings and reports | Group settings logically; place infrequent moderation/ownership actions below everyday settings. Reports were inspected in an empty state, not a populated moderation workflow. |
| Invite contact/link, invite preview/error, invitation inbox/detail | Keep concise approval/privacy explanations. Rename Sent to Accepted and retain paste-link access with populated data. Error fixtures are not evidence of a production outage. |
| Chats list/new chat, group/direct threads and incoming request | Keep familiar list + conversation structure. Fix double scaling first; distinguish incoming bubbles from the white page and keep request acceptance clear. Search remains explicitly limited to loaded data. |
| Messaging privacy | Only fixture error state captured; healthy privacy-choice layout is not visually validated. Do not redesign an imagined successful state. |
| Events list/detail/new/edit/attendees | Normal-size pages are coherent. Reflow list rows at large text; simplify creation forms, show options progressively and retain timezone/RSVP clarity. Attendees captured empty. |
| Poll list/create/detail/voters | Solid base. Remove duplicate title/introduction, reduce always-visible counters and group optional settings. Keep named/anonymous vote explanations accurate. |
| Own profile, Saved, other-member profile, edit profile | Keep shared cards. Use a more compact identity area when there is no actual cover. Separate settings access from content and remove duplicated “Recent Memories” empty headings. Preserve optional private personal details. |
| Search | Current loaded-data limitations are stated honestly. Broader server search is a separate API feature, not a visual fix. |
| Privacy/blocking, account/password | Reduce explanatory repetition and distinguish primary account actions from destructive ones. Do not remove meaningful logout/password consequences. |
| Devices | Make current-device status and last activity easy to scan; expand technical IP/version/location details on demand. The old 1.0.12(13) shown is fictional device-history data, not the current build. |
| Notifications | Isolated component capture only, with capability enabled through a fixture. Group permission status, category controls and quiet hours. Real device permission/push behavior was not audited. |
| Activity and Albums | Activity is explicitly unavailable; Albums is capability-off with only its heading. No healthy live feature experience is claimed. Hide unavailable entry points where appropriate rather than inventing feature content. |

## Manual scorecard

Editorial assessment out of five, based only on the evidence above; not automated performance or accessibility certification.

| Area | Assessment | Reason |
|---|---|---|
| First impression | 3/5 | Consistent foundation; weak hierarchy and overexplained forms. |
| Onboarding | 3/5 | Clear account path, excessive supporting copy and unfinished recovery messaging. |
| Navigation | 3/5 | Familiar main destinations; ambiguous creation and invitation labels. |
| Core flow | 3/5 | Feed/chat/event structure is recognizable; viewer controls are misleading. |
| Accessibility | 2/5 | Proven double chat scaling and severe large-text event compression. Native assistive technology not tested. |
| Trust | 3/5 | Honest privacy messaging, undermined by inert controls and roadmap copy. |
| Monetization | N/A | No purchase/paywall/advertising flow assessed. |
| Store readiness | Not judged | No store listing, physical-device acceptance or full release review in this audit. |

## Suggested first-screen copy

**Keep your people close.**

Share Memories, chat and make plans in private Circles.

Primary: **Create account**. Secondary: **Log in**.

Use existing supported features only. Password recovery needs a real backend flow before it can be offered.

## Quick wins and acceptance order

Likely sub-hour copy-only changes: rename Sent to Accepted, standardize Circle/InCircle wording, remove duplicate page headings and remove planned-feature text. A persistent paste-link entry and viewer interaction changes require behavior checks, not just copy edits.

Implement the five priorities in order, then capture the same matrix. Validate that photo actions work, chat applies scaling once, event/nested names remain readable at 200%, invitation tabs match their data, and forms retain keyboard-safe actions. Finally check the actual iPhone and Android builds before declaring the visual work accepted. No new runtime implementation or build was performed for this audit.
