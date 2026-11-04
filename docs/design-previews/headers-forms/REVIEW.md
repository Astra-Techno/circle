# Social 1.1 — compact headers and consistent forms

4 November 2026. Owner approved the compact header proposal and requested
consistent form-element sizes and spacing across all pages. Implemented in
actual shared Flutter widgets/theme; these are renders of production screens
with fictional test data, not replacement mock-ups.

## Header review and decisions

| Page family | Finding | Implemented treatment |
|---|---|---|
| Home | Logo/tagline/three actions competed with the composer |32px authentic logo, one title, Search and Activity; no tagline or redundant Chats shortcut |
| Circles | Brand lockup and colored create button differed from other titles |One Circles title, Search and New group in matching circles |
| Chats | Create sat beside title; conversation used separate control styling |Search/New chat at right; conversation keeps identity, with matching Back/options controls |
| Events | Header actions needed the same placement and sizing |Search/New event when creation is allowed; details/forms use the shared Back/title row |
| Profile | Repeated navigation displaced useful settings access |Search and Account settings; existing Profile actions remain available |
| Details/auth/invite | Toolbar heights and Back icons differed |One shared title scale, Lucide Back/Close, quiet circular Back targets |
| Group detail tabs | Sticky tab bar is content navigation, not another page heading |Retained below the standard page header |

Root bars use a56px baseline and grow at large text sizes. Icons are22px,
painted circles40px, touch targets48px. Titles stay on one line with ellipsis
where needed; semantic labels retain complete action names.

Home now reads “Share a memory…” and offers a slim Photo/Event/Poll row.
Unsupported Video is hidden. Event and poll shortcuts preserve the chosen
circle. At large text sizes the action row wraps instead of clipping controls.

## Shared form rules

- Standard inputs:56px minimum height,16px type and internal padding,10px corners.
-16px between editor fields;24px between sections;16px form side margins.
- Primary/secondary form buttons use56px minimum height.
- Floating labels, helper/error text, prefix/suffix controls and focused borders
  share one InputDecorationTheme. Errors and multiline text can grow.
- Event/poll fields no longer touch. Memory captions use the same outlined
  multiline input treatment. Existing sign-in, settings and dialogs inherit
  the input geometry; message composers retain their purpose-specific layout.
- Feedback is raised above pinned action areas on editor/conversation/detail
  routes. Ordinary pages retain normal notice placement. Event save, poll retry
  and invitation reset were explicitly rechecked after this adjustment.
- The test scroll helper now ignores zero-range internal text viewports when
  searching for off-screen controls. It no longer tries to scroll SelectableText
  instead of the page.

## Review captures

27 routes in four light/dark/phone/tablet/200% layouts:108 renders. Selected
Home, Circles, chat, event creation, profile editing and password screens were
visually inspected. Missing fake endpoints may show real loading/error/empty
states; captures do not establish backend/native-picker behavior.

| Route | Phone light |
|---|---|
| chats | [Render](-chats-393-1.0-light.png) |
| chats-c-501 | [Render](-chats-c-501-393-1.0-light.png) |
| chats-new | [Render](-chats-new-393-1.0-light.png) |
| chats-privacy | [Render](-chats-privacy-393-1.0-light.png) |
| compose-group-3 | [Render](-compose-group-3-393-1.0-light.png) |
| events | [Render](-events-393-1.0-light.png) |
| events-e-91 | [Render](-events-e-91-393-1.0-light.png) |
| events-e-91-attendees | [Render](-events-e-91-attendees-393-1.0-light.png) |
| events-e-91-edit | [Render](-events-e-91-edit-393-1.0-light.png) |
| events-new-group-3 | [Render](-events-new-group-3-393-1.0-light.png) |
| groups | [Render](-groups-393-1.0-light.png) |
| groups-g-3 | [Render](-groups-g-3-393-1.0-light.png) |
| groups-g-3-invite | [Render](-groups-g-3-invite-393-1.0-light.png) |
| groups-g-3-invite-link | [Render](-groups-g-3-invite-link-393-1.0-light.png) |
| groups-g-3-settings | [Render](-groups-g-3-settings-393-1.0-light.png) |
| groups-new | [Render](-groups-new-393-1.0-light.png) |
| home | [Render](-home-393-1.0-light.png) |
| home-memory-4 | [Render](-home-memory-4-393-1.0-light.png) |
| people-2 | [Render](-people-2-393-1.0-light.png) |
| search | [Render](-search-393-1.0-light.png) |
| you | [Render](-you-393-1.0-light.png) |
| you-account | [Render](-you-account-393-1.0-light.png) |
| you-account-password | [Render](-you-account-password-393-1.0-light.png) |
| you-account-sessions | [Render](-you-account-sessions-393-1.0-light.png) |
| you-edit | [Render](-you-edit-393-1.0-light.png) |
| you-invitations | [Render](-you-invitations-393-1.0-light.png) |
| you-privacy | [Render](-you-privacy-393-1.0-light.png) |

## Validation and release identity

Formatting/analyzer clean. Header/form/style checks:8 passed. Invitation reset,
event save and poll retry regressions:3 passed. Full integration:698 passed,
1 skipped,23 failed (22 golden pixel differences plus a token-placement guard
subsequently corrected and retested in the8 passing checks). No affected
functional regression remains. This is not an all-green full-suite result. Existing Windows golden baselines
are unchanged; this intentional visual change still needs screenshot review.
Source version1.0.28+31; Account identifies **Social 1.1**. A new main TestFlight
run will be linked after commit. The earlier Social1 build and footer-only build
do not contain this combined header/form revision.

Reproduce from mobile/:

```sh
CIRCLE_CAPTURE_DESIGN=true CIRCLE_DESIGN_CAPTURE_DIR=../docs/design-previews/headers-forms flutter test test/header_form_layout_test.dart test/consistent_design_review_test.dart
flutter analyze
flutter test
```
