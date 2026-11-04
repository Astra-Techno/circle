# Social 1 — app-wide style audit

4 November 2026. Owner requested a Facebook-inspired professional visual system
across all pages. This replaces the prior Home-reference typography direction.
CIRCLE retains its own purple identity, authentic logo and existing functionality.

## Implementation

- One bundled font: Roboto, regular 400 and semibold 600. Material TextTheme and
  explicit CircleTextStyles now resolve to one hierarchy. Home copy is 16px, not 12.
- Shared 24px page titles, 20px sections, 16px card names/body, 13px metadata,
  14px labels, 15px buttons and 12px navigation/helper labels. Text scales normally.
- Consistent Lucide outline icons and 48px minimum controls. The Material filled
  heart remains only for the selected chat-reaction state, not a second icon vocabulary.
- Gray canvas, white content surfaces, restrained borders, 12px cards and 10px
  controls. Dark theme uses the same semantic roles. Purple marks primary actions.
- Full-width bottom navigation: Home / Circles / Chats / Events / Profile.
- Account shows **Interface version: Social 1**, allowing the installed interface
  to be identified independently of a repository screenshot. Version 1.0.27+29.

## Route renders

27 signed-in routes were checked at 393×852 light/dark,320×1000 dark 200% and
900×1100 light 200%.108 actual Flutter captures are included. Each test verifies
that navigation reached the intended route and no rendering exception occurred.
Selected root/detail/form/account/large-text captures were visually inspected.
Fixtures use only fictional data. Native contact pickers cannot run in widget
tests; loading/error/empty states from missing fixture endpoints are captures of
those states, not proof of live backend or device behavior. Prior snackbars are
cleared between routes so one screen's message does not contaminate another.

| Route | Phone light capture |
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

## Presentation-file audit

Every production presentation file below inherits the same Material theme; raw
font sizes/families remain confined to core tokens. Existing interaction tests
exercise forms, invitations, privacy, photos, polls, chat and security flows.
This source audit is broader than the 27-route capture catalog. Unsupported
features remain gated; no new demo or backend capability was added.

- `lib/features/albums/presentation/album_detail.dart`
- `lib/features/albums/presentation/albums_tab.dart`
- `lib/features/albums/presentation/event_album.dart`
- `lib/features/auth/presentation/access_design.dart`
- `lib/features/chat/presentation/live_chat_design.dart`
- `lib/features/chat/presentation/live_chats.dart`
- `lib/features/events/presentation/event_visuals.dart`
- `lib/features/events/presentation/live_events.dart`
- `lib/features/groups/presentation/circle_groups.dart`
- `lib/features/groups/presentation/contact_invitation_entry.dart`
- `lib/features/groups/presentation/contact_invitation_inbox.dart`
- `lib/features/groups/presentation/contact_invite_screen.dart`
- `lib/features/groups/presentation/group_detail.dart`
- `lib/features/groups/presentation/group_invite.dart`
- `lib/features/groups/presentation/group_members.dart`
- `lib/features/groups/presentation/group_photos.dart`
- `lib/features/groups/presentation/group_reports.dart`
- `lib/features/groups/presentation/group_settings.dart`
- `lib/features/groups/presentation/invite_link_screen.dart`
- `lib/features/groups/presentation/invite_share_actions.dart`
- `lib/features/memories/presentation/circle_memories.dart`
- `lib/features/memories/presentation/memory_card.dart`
- `lib/features/memories/presentation/memory_compose.dart`
- `lib/features/memories/presentation/memory_detail.dart`
- `lib/features/memories/presentation/memory_grid.dart`
- `lib/features/memories/presentation/memory_photos.dart`
- `lib/features/memories/presentation/memory_reactions_sheet.dart`
- `lib/features/memories/presentation/mention_text.dart`
- `lib/features/memories/presentation/scoped_memory_list.dart`
- `lib/features/moderation/presentation/report_sheet.dart`
- `lib/features/moderation/presentation/server_reports.dart`
- `lib/features/notifications/presentation/activity_screen.dart`
- `lib/features/notifications/presentation/push_presentation_host.dart`
- `lib/features/notifications/presentation/server_push_settings.dart`
- `lib/features/polls/presentation/live_polls.dart`
- `lib/features/profile/presentation/account_security_screens.dart`
- `lib/features/profile/presentation/circle_you.dart`
- `lib/features/profile/presentation/person_avatar.dart`
- `lib/features/profile/presentation/person_profile.dart`
- `lib/features/profile/presentation/profile_edit.dart`
- `lib/features/profile/presentation/profile_photo.dart`
- `lib/features/profile/presentation/server_blocking.dart`
- `lib/features/search/presentation/search_screen.dart`
- `lib/features/workspace/presentation/feature_gate.dart`
- `lib/features/workspace/presentation/group_visuals.dart`
- `lib/features/workspace/presentation/workspace_view.dart`

## Validation and release

Formatting/analyzer clean. Focused suite 47 passed; final welcome/access checks 4 passed.
Full suite 694 passed,1 skipped,22 screenshot comparisons failed; no functional
failures. The final decorative welcome-heart icon change was followed by4 passing
accessibility/keyboard/large-text checks. This is not an all-green full suite. Existing Windows golden
baselines were not regenerated on Linux. Pixel differences are expected after
this deliberate design change and still need visual review. No claim of exact
Facebook equivalence or physical-device acceptance is made. The new TestFlight
run must be linked to the pushed source SHA; upload and Apple processing are
separate from tests. After installing, check Profile → Account for Social 1.

Reproduce: `CIRCLE_CAPTURE_DESIGN=true flutter test test/consistent_design_review_test.dart`.
