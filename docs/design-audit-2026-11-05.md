# Circle design audit — 5 November 2026

**Recommendation:** refine the existing product into one consistent social app before adding more features. Keep Circle purple, the supplied brand artwork, the five destinations and current privacy model. Use Facebook's clear Memory hierarchy, WhatsApp's compact conversation patterns and Telegram's direct navigation as interaction references. Do not combine three different visual systems or copy their branding.

This is the suggestions-first audit requested by the owner. **No production Dart, dependencies, API, SQL, version or release artifacts were changed.** The briefly started local implementation draft was removed. Source reviewed: main at `732535a`, pulled safely and already current.

## Evidence and limits

Used the installed **App Audit**, **Product & App Architect** audit guidance and **Hugeicons** library-selection guidance. Product Design routing/capture guidance was also inspected, but its browser-driven audit could not run: no browser tool/Browser skill is exposed in this session. This report is a native Flutter code/render review, not a completed interactive Product Design browser audit. Hugeicons explicitly recommends retaining an existing icon library; Circle already uses Lucide, so no second library was installed.

- Captured **160 Flutter test renders** in this run: 27 routes at four configurations (108), 23 additional auth/poll/tab/state renders, and 29 notification-enabled/photo/conversation/keyboard renders. Configurations include 393px light/dark, 320px at 200% dark and 900px at 200% light. These are automated test renders, not 160 separate pages.
- Visually inspected the light-phone route set, additional contact sheets and selected dark/large-text, photo, conversation, keyboard and notification screens. A passing capture only establishes no caught layout exception; it does not establish good design or exhaustive visual acceptance at every configuration.
- Used fictional fixtures only. The single-item lists explain much of the blank canvas in these captures; that space is **not evidence of missing production data**. Photo examples are bundled test illustrations, not live private-image delivery.
- Missing fixture endpoints show error states in Messaging privacy, Invitations and Devices. Their successful layouts are code-reviewed only. Notifications has a separate successful render with the compile-time push flag enabled; switch values are fixture data, not a finding about production defaults or saved preferences.
- No real login, successful upload, two-person messaging, real native contact/photo picker, push delivery, screen-reader session, physical-device animation or production timing was tested. Emoji missing-glyph boxes in the Linux photo capture do not establish an iOS/Android font defect.
- HTML page checker was not run: the reviewed product is Flutter, not supplied HTML.

## Scorecard

Ratings are reviewer judgments from the evidence, not plugin measurements or production health scores.

| Area | Rating | Evidence |
|---|---|---|
| First impression | 3/5 | Root pages share purple, white/gray surfaces and headers; Groups duplicates cards and deeper pages use different content patterns. |
| Onboarding | 3/5 | Welcome explains private sharing; auth uses generic Account title and a large brand block. Login says recovery is unavailable. Completion not tested. |
| Navigation | 3/5 | Five labeled destinations and dedicated conversation view are clear; group Chat/Events tabs are intermediary cards, and large-text dock labels truncate. |
| Core-flow design | 3/5 | Pinned conversation composer and event RSVP are useful; repeated introductions, form action placement and generic state panels add friction. Service correctness not scored. |
| Accessibility | 3/5, provisional | Shared 48px targets and scalable fields are good; 320px/200% navigation readability and light-theme send-icon contrast need work. Not a compliance verdict. |
| Trust and clarity | 3/5 | Exact-group audience and privacy explanations are useful; generic titles and build-dependent absolute notification wording need precision. |
| Monetization | Not applicable | No payment flow reviewed. |
| Store readiness | Not judged | No native installation, store listing or release review in this task. |

## Main findings, in implementation order

| ID | Priority / effort | Evidence and issue | Smallest useful improvement | Acceptance |
|---|---|---|---|---|
| D01 | High / small | [320px, 200% Account](design-previews/plugin-audit-2026-11-05/large-text-navigation.png): dock labels truncate and crowd icons. No overflow exception was thrown. | Allow accessible navigation height/spacing to grow with text while preserving the corrected normal-size footer clearance. Preserve the owner's compact normal-size font and profile avatar. | Readable labels and centered icons at 100/150/200%; no extra normal-size footer gap or obscured final controls. |
| D02 | High / small | [Conversation](design-previews/plugin-audit-2026-11-05/conversation.png): dark send glyph on a purple filled button has weak visible separation. `IconButton.filled` and shared icon themes need examination. | Set the filled-action foreground from `onPrimary` and use the same treatment for message/comment send. Verify contrast programmatically before finalizing. | Send icon visually distinct in both themes; at least 3:1 non-text contrast for the enabled control. No claim that every icon already meets this. |
| D03 | High / small–medium | [Page sheets 4–5](design-previews/plugin-audit-2026-11-05/pages-4.png): Privacy and blocking has Profile in its toolbar; login/register both say Account. Direct-open New/Edit Event captures lack an explicit Back/Cancel control. | Give each detail/form a meaningful title and a visible exit, including a safe fallback when no navigation history exists. Remove redundant second headings. | Correct titles; Back/Cancel reachable from deep links; existing dirty-form protection retained. |
| D04 | Medium / small | [Circles](design-previews/plugin-audit-2026-11-05/circles.png): the same circle appears under Pinned and All. In `circle_groups.dart`, Pinned is automatically derived from activity rather than a user pin preference. | Show the group tree once. If a recent shortcut section is retained, label it Recent and use small shortcuts; do not imply a saved pin action. Preserve nested context/collapse controls. | No duplicate full-size circle cards or misleading pin state; nested membership/tree behavior unchanged. |
| D05 | Medium / medium | [Chats](design-previews/plugin-audit-2026-11-05/chats.png): padded standalone cards, no inbox-specific search or unread/archive controls. Archive state exists in API/code but is not a clear inbox destination. | Use compact avatar-led rows with consistent preview/time/unread alignment; add discoverable Unread/Groups/Archived controls and chat search with honest scope. Current header Search opens global search. | Long names/large text reflow; mute/pin/request states remain clear. Local search explicitly says loaded chats; complete server search requires a reviewed API change. |
| D06 | Medium / medium | [Group Events tab](design-previews/plugin-audit-2026-11-05/group-events-tab.png), [extra sheet 4](design-previews/plugin-audit-2026-11-05/extra-pages-4.png): Chat/Events tabs show a generic panel and another Open button. | Put meaningful existing content in the selected tab or navigate directly on selection; keep full-screen chat for composing. Do not imply tab labels already display inline content. | Opening Chat/Events gives useful content without an unnecessary second entry screen; exact-group access remains enforced. |
| D07 | Medium / medium | [Composer](design-previews/plugin-audit-2026-11-05/composer.png), [forms](design-previews/plugin-audit-2026-11-05/pages-2.png): 56px field tokens already exist, but forms vary in introduction size, photo controls, section density and CTA position. | Standardize one form shell: short introduction, visible audience, labeled Add photos, consistent field/section gaps and one predictable save area. Use counters on demand where appropriate. | Keyboard/error text never covers Save; existing drafts, validation and leave guards work; 200% text scrolls without clipped controls. |
| D08 | Medium / small–medium | [Empty/error sheets](design-previews/plugin-audit-2026-11-05/extra-pages-1.png): the same large circle icon and headline card represents no attendees, errors, unavailable pages and empty subgroups. Some panels stretch through most of the screen. | Separate empty/error/access states. Use a relevant icon, concise explanation, correctly sized panel and one next action. Keep stable content during refresh. | Empty is distinguishable from loading/error/no access; Retry only retries a failed operation; no permission leak. |
| D09 | Medium / small | [Profile](design-previews/plugin-audit-2026-11-05/profile.png): large generic mountain cover, repeated camera affordances and scattered standalone settings cards make Profile feel like a settings dashboard. | Keep a compact identity header and a distinct Memories area; group settings into fewer consistent rows. Use a quiet cover fallback without suggesting content exists. | Own and other-person profiles share hierarchy, with edit/message/admin controls shown only when applicable. |
| D10 | Medium / small | [Event list](design-previews/plugin-audit-2026-11-05/events.png): date/title/location are helpful, but list lacks clear Upcoming/Past organization; detail and editor use different heading patterns. | Organize events by time, show the circle name when viewing all circles, keep the date badge and pinned RSVP. Avoid obscure raw timezone/date strings in editors. | Timezone-aware grouping across boundaries, canceled/full/answered states clear; filtered pagination cannot silently omit relevant later rows. |
| D11 | Medium / small–medium | [Poll](design-previews/plugin-audit-2026-11-05/poll.png): stacked Refresh, options, Submit, Add option, See who voted and Close compete at the same level. Single-choice poll visually uses square checks. | Prioritize the question, options and vote action. Use radio affordances for single choice, checks for multiple, progress only when results are permitted; put organizer actions under More. | Hidden/anonymous results remain hidden; voting, change restrictions and close permissions retain tests. |
| D12 | Medium / small | [Auth sheets](design-previews/plugin-audit-2026-11-05/extra-pages-3.png): large branding and location-country action push essential fields/actions lower; login explains unavailable recovery. | Shorten repeated copy and keep login/create-account actions prominent. Keep country selection explicit; make location assistance secondary. Recovery is a separate real feature, not a decorative link. | Short phones/keyboard/large text remain usable; no invented OTP/recovery behavior. |
| D13 | Low–medium / small | [Notifications](design-previews/plugin-audit-2026-11-05/notifications.png): repeated choice/connection explanations and generous gaps delay category controls. [Account](design-previews/plugin-audit-2026-11-05/pages-4.png) uses an absolute no-notifications sentence only when the capability is off. | One concise device status/explanation, then categories and quiet hours. Make Account wording accurate for unavailable builds without making an absolute service-wide promise. | Preserve saved opt-outs, per-device permission and quiet hours; do not change defaults for a visual redesign. |
| D14 | Low / small | `docs/design-system.md` still calls Social 1 Roboto-only, while `circle_typography.dart` uses Jakarta headings and Roboto body. Some feature icons use direct Lucide imports instead of central semantic mappings. | Document the actual accepted font pairing, centralize common icon meanings/sizes and reuse existing components. Do not introduce another library just because its plugin is installed. | One documented type hierarchy and semantic icon mapping; design guard passes. |

## Page and state coverage

“Captured” means a current fictional Flutter render exists, not a successful production operation. Contact sheets retain original filenames so the visible state is traceable. “Code only” is a named evidence gap, not an all-clear verdict.

| Flow step / page family | Observed state and health | Suggested direction |
|---|---|---|
| 1. Welcome | Captured light/dark; clear privacy proposition, long first screen. | Shorten the path to Create account and Log in; keep canonical artwork. |
| 2. Register | Captured light/dark; usable field hierarchy, generic Account title and large branding. | D03/D12; do not add fake OTP. |
| 3. Log in | Captured light/dark; password visibility exists; recovery explicitly unavailable. | D03/D12; recovery needs backend scope. |
| 4. Home/Memories | Captured text/photo layouts and root variants; coherent composer and card anatomy. | Retain audience/privacy, unify secondary icon weights/actions; no filler content to cover sparse data. |
| 5. Memory detail/comments | Captured; two headings and separate comment controls can be tightened. | Shared detail header, clearer comment entry and matching send action. |
| 6. Photo grid/gallery/viewer | Photo grid and gallery empty state captured; real uploaded viewer/zoom code only. | Consistent crop/count overlays and viewer chrome; preserve signed access, rendition selection and bounded decode. |
| 7. Create Memory | Captured with selected group; photo placeholder is an unlabeled plus visually. | D07; labeled add-photo tile, clear audience, preserved drafts/uploads. |
| 8. Reactions/report sheets | Presentation code reviewed; open-sheet interactions not captured. | Shared sheet title/close/action styles; verify gestures also have accessible buttons. |
| 9. Circles list | Captured; duplicated cards and misleading automatic pins. | D04; clear search and one hierarchy. |
| 10. Create group | Captured; large introduction and different CTA placement from other forms. | Shared form shell, keep explicit private ownership/consent explanation. |
| 11. Group Memories/header | Captured; cover plus metadata plus action rows push content down. | Compact collapsible identity; keep tabs, subgroup identity and audience. |
| 12. Group Chat/Events | Both tab panels captured; healthy entry controls but an extra navigation step. | D06. |
| 13. Members/Subgroups | Members list and empty Subgroups captured. | Compact role/member rows; contextual create action and smaller empty panel. Populated nested tree needs a separate visual pass. |
| 14. Group settings | Captured; useful role/rule explanations, repeated Settings heading. | D03/D07; separate normal settings from ownership/destructive actions. |
| 15. Invite people/link | Captured invite entry and link-creation state; native contact picker unavailable in runner. | Compact share actions, expiry/reset grouped, clear invite audience. Do not claim native picker failure in production. |
| 16. Invite acceptance | Invalid-link state captured; success/pending/expired acceptance layout code only. | Distinguish recoverable link problems and pending approval; maintain no content access before membership. |
| 17. Invitation inbox/detail | Error-state inbox captured; success and invitation detail code only. | Keep Received/Sent/Expired consistent; per-item accept/decline should be unambiguous. |
| 18. Chat inbox | Captured with last preview/unread; sparse card layout. | D05; honest search scope and archive destination. |
| 19. New chat/contact list | Captured one eligible member; no visible local search. | Compact eligible-person rows; member search with honest pagination scope. |
| 20. Conversation | Incoming/outgoing, both themes and keyboard inset captured; pinned composer is good. | D02; refine bubble spacing/name/time hierarchy, not a wholesale rebuild. Requests, edit/reply/report/unsend menus remain code-only in this audit. |
| 21. Messaging privacy | Error state captured; successful controls code only. | Correct state/retry design; never claim preference enforcement from a render. |
| 22. Events list | Captured; recognizable date badge. | D10; time grouping and clear group context. |
| 23. New/edit event | Captured; date strings and explicit exit need consistency. | D03/D07/D10; preserve timezone semantics and permission checks. |
| 24. Event detail/attendees | Detail and empty attendees captured; clear pinned RSVP. | Keep RSVP; smaller attendee empty state and clear event identity. Populated attendee actions code only. |
| 25. Poll list/create | Captured light/dark; functional hierarchy, repeated introductions. | Shared list/form treatment and contextual audience. |
| 26. Poll detail/voters | Named fixtures captured light/dark; too many peer-level actions. | D11; hide counts/identities whenever policy requires. |
| 27. Own/other profile | Both captured; identity useful but cover fallback dominates. | D09; clear distinction between personal content and settings. |
| 28. Edit profile | Captured; good section boundaries, many counters/gaps. | D07; preserve truthful private/public field descriptions. |
| 29. Privacy/blocking | Empty captured; toolbar incorrectly says Profile. | D03/D08; populated blocked list/unblock interaction code only. |
| 30. Account/password | Captured; conditional capability copy and generic state panel. | D07/D13; keep password-change logout explanation. |
| 31. Devices | Error captured; successful session/revoke list code only. | Useful device names, clear current-device marker, safe revoke controls. |
| 32. Notifications/quiet hours | Flag-enabled settings entry captured; off-build gate also captured. Lower quiet-hours controls code reviewed only. | D13; compact status/categories, expandable help. No push delivery finding. |
| 33. Global search | Initial captured; populated results code only. | Distinct result sections, shared search/clear control; retain debounce and exact access scope. |
| 34. Reports/admin | Empty admin queue captured; report action screens/code reviewed. | Compact contextual admin list and clear action severity; populated cases/actions need capture. |
| 35. Activity/Albums | Activity unavailable gate captured; unsupported album routes code reviewed. | Keep unsupported features hidden; do not decorate unfinished features as if live. |

## Proposed unified direction

1. **One Circle identity:** existing purple, white/light-gray surfaces and dark equivalents; current bundled heading/body font pairing; one consistent Lucide outline set. A small canonical logo on Home, meaningful text headers elsewhere.
2. **Three clear surface patterns:** flat compact rows for chat/member/settings lists; photo-led cards for Memories/events; one shared form layout. Avoid turning every item into a floating panel.
3. **Predictable sizing:** reuse current 16px body, 13px metadata, 24px page-title and 48px target tokens. Preserve the owner's smaller normal-size bottom labels. Allow accessible growth instead of fitting large text inside a fixed compact dock.
4. **Action hierarchy:** one main action per context; secondary edits/admin controls under labeled menus. Use short verbs such as Share Memory, Create event, Save changes and Submit vote consistently.
5. **Real interaction polish:** content-preserving refresh, stable thumbnail placeholders, clear send/retry states, meaningful date groups and smooth keyboard behavior. Keep the recent performance improvements and private-media safeguards.

Rewritten first-screen suggestion, using only existing product facts: **“Your people. Shared memories.”** / “Share memories, chat and plan events with your private circles.” / **Create account**; secondary **Log in**. This is suggested copy only, not an implemented screen.

Quick wins to implement first: correct screen titles; fix filled-send foreground; remove duplicate automatic pin cards; shorten repeated introductions; label Add photos; make empty-state icons/context specific. Larger work follows with inbox controls, direct group-tab content and grouped profile/settings layouts.

## Validation and delivery

- Safe pull: main already current; no other work discarded.
- Existing consistent-design capture suite: **5 tests pass**, including 108 route/configuration renders.
- Temporary additional capture harness: **5 tests pass** without push and **9 pass** with `CIRCLE_PUSH_ENABLED=true`. The temporary harness was removed after capture; it did not enter production source.
- Existing access/form/motion/design-token checks: **19 pass, 4 fail**. All four failures are access-screen golden comparisons against Windows images on Linux (welcome/login/register/register_dark); baselines were not regenerated. These results do not certify every page's accessibility.
- No app build, backend deployment or TestFlight run was performed for this audit. The installed application remains unchanged.

Evidence index: [Home](design-previews/plugin-audit-2026-11-05/home.png), [Chats](design-previews/plugin-audit-2026-11-05/chats.png), [Circles](design-previews/plugin-audit-2026-11-05/circles.png), [Events](design-previews/plugin-audit-2026-11-05/events.png), [Profile](design-previews/plugin-audit-2026-11-05/profile.png); route sheets [1](design-previews/plugin-audit-2026-11-05/pages-1.png), [2](design-previews/plugin-audit-2026-11-05/pages-2.png), [3](design-previews/plugin-audit-2026-11-05/pages-3.png), [4](design-previews/plugin-audit-2026-11-05/pages-4.png), [5](design-previews/plugin-audit-2026-11-05/pages-5.png); additional sheets [1](design-previews/plugin-audit-2026-11-05/extra-pages-1.png), [2](design-previews/plugin-audit-2026-11-05/extra-pages-2.png), [3](design-previews/plugin-audit-2026-11-05/extra-pages-3.png), [4](design-previews/plugin-audit-2026-11-05/extra-pages-4.png).
