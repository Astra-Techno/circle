# Circle detail and shared Memory cards — 6 November 2026

## Brief and evidence

The owner requests the same Home Memory cards on Circle detail and Profile, white page backgrounds, the existing Circle icon style, removal of the Circle tabs and duplicate Share/Polls buttons, and a more polished Circle page. Source1.0.34+39, interface markerSocial2.2.

The **App Audit**, **App Editor** and **Hugeicons** plugin guidance was read. The icon guidance explicitly says to retain an installed icon family, so existing Lucide icons are preserved; no mixed library or new dependency. Product Design's browser-capture route was inspected but no browser-control tool is exposed here. This is a native screenshot/code/Flutter-render review, not a completed interactive Product Design browser audit. No web-page checker score or full accessibility certification is claimed.

Evidence: the owner's iPhone screenshot in this conversation; fresh real-Flutter renders from `circle_surface_review_test.dart`, using fictional accounts/data and the actual application widgets. [Before](design-previews/social-2.2/01-circle-before.png). Desktop renders validate structure and layout with Inter; they do not preview native Apple font rendering or prove production photo delivery.

## Audit findings and applied corrections

1. **Circle overview — repeated navigation crowded the page.** The screenshot and before render show an icon row, a five-tab strip, then another Share/Polls row. Keep the supported icon shortcuts and remove the other two rows. Memories now follow the header directly.
2. **Identity — heavy filled stat blocks competed with the name and cover.** Use the shared page-title scale and quiet metadata links. Member count opens Members; InCircles opens the existing nested-circle list. Owner/admin and listed/hidden context remain visible. Cover/avatar editing and refresh remain permission-aware.
3. **Actions — one fixed row overflowed on phones/large text.** Keep40px icon paint within48px-or-larger controls, measure scaled labels and reflow the row. Chat/Events/Polls respect capability flags. Create now opens the Memory composer preselected to this exact Circle. New InCircles creation remains in the InCircles destination with the existing membership rule and keyboard-aware sheet. Members/requests and Albums remain reachable without the tab strip; Back returns to the Circle.
4. **Memories — Profile used a grid, Saved used text rows, and Circle content had different outer insets.** Home, Circle detail, Your Memories, Saved and other members' profiles now render `CircleMemoryCard`, retaining audience context, private photo handling and reaction/comment/save/menu actions. Shared hairline card boundaries separate white cards on the white canvas. Poll-only Memories keep a readable question. Card actions reflow at large text instead of truncating Comment.
5. **Canvas — root pages were grey while detail/forms were white.** Theme scaffold/surface was already white; explicit shell and Home overrides supplied grey. Both now use the shared surface; chat wallpaper uses white in light mode. Semantic input fills, image placeholders and icon surfaces remain distinct. Dark mode retains its explicit dark surfaces.
6. **Profile tabs — a real widget assertion blocked the new design.** Set an explicitly scrollable, start-aligned Your Memories/Saved bar to match the shared theme. The Circle detail tab bar is removed; the Profile view switch remains.

## Journey and access checks

- Circle → Memories: same Home card; group-scoped query and its existing cursor paging retained. Pull to refresh refreshes workspace and invalidates this Circle's timeline, with a mounted check.
- Circle → Create: opens `/compose?group=<id>`; no new creation permission or API.
- Circle → Members/InCircles: separate scoped routes, existing member-management/join/request logic, and a fresh workspace membership check before content. Hidden/nonmember data is not exposed.
- Profile → Your Memories: only the viewer's loaded workspace Memories; Load older Memories stays available. This remains loaded-page filtering, not a new author-specific server query.
- Profile → Saved: only the existing saved query; Home cards resolve the current accessible group before display. Another author's unsaved/own-page content is not substituted.
- Other member profiles retain shared-membership gating and only use already-visible workspace Memories.

No backend, SQL, API contract, signing identity or dependency changed. The earlier empty-inbox-only paste-invite discovery finding is outside this design batch and is not claimed fixed. Production photos and physical-device acceptance remain unverified. Android signing material remains absent; existing public APK downloads are unchanged.

## Verification

Analyzer clean; format clean. Full local functional run:734 passed,2 failed,1 skipped (22 platform-specific image comparisons excluded). Both failures were journey expectations for removed buttons/tabs; after updating them to Create/header actions, all21 tests in the affected two files passed. The same runtime source passed the remaining734 checks, including6 new shared-card/white-canvas/scoped-route tests and112 route/configuration renders. Windows full-suite/baseline comparison follows below; a local rerun of every passing check is unnecessary for test-only expectation edits.

Fresh after renders: [Circle](design-previews/social-2.2/02-circle-after.png), [Profile](design-previews/social-2.2/03-profile-after.png), [Circle at200%](design-previews/social-2.2/04-circle-large-text.png), [Profile at200%](design-previews/social-2.2/05-profile-large-text.png). All112 page/configuration images were inspected in contact sheets (28 routes each at393/light,393/dark,320/200% dark,900/200% light), with representative Circle/Profile images opened individually. Some fake endpoints intentionally render honest error/empty states; this is not production behavior evidence. Historical failures are not final acceptance.
