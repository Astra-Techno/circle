# Original CIRCLE experience — 23 October 2026

Owner requested original design and implementation without supplying a reference. The design extends the existing access preview into the default app. No approved Figma frames exist; Figma tools remain absent from this conversation. Proceed with original Flutter components and truthful visual QA, without claiming a Figma match or waiting for another connection.

## Screen specifications before implementation

- Welcome: existing warm original artwork and open registration/login, plus an explicit fictional-data tour. Mobile + password preview clears inputs and opens an empty workspace. Registration never silently joins sample groups.
- Main shell: Home, Chats, Groups, Events, You; every icon has a label and every branch retains its navigation stack through StatefulShellRoute.indexedStack.
- Home: quiet mock banner, editorial Memories heading, group-filter chips, audience-labeled cards, local illustrations, reactions, saves and details/comments. Empty workspace has Create group and Join guidance. Compose selects only exact memberships and supports text initially.
- Groups: searchable, indented joined-group hierarchy; four-level fictional college example alongside family, work and club. Group details show tappable ancestor breadcrumbs, group identity, exact role, Memories and direct subgroups. Create root/subgroup requires name and type; depth limit belongs to the domain repository. Full approval/invite/role-management UI is a later UI-2 increment.
- Chats: group conversation directory with explicit local-preview/no-delivery copy and a truthful chat-phase empty state in each group. Real messaging and DMs are UI-5; no fake send controls or activity indicators.
- Events: fictional group-scoped cards with local Going/Maybe/Not going choices. Full creation/calendar/guest counts remain UI-4.
- You: fictional identity, appearance, saved Memories and clear-session action. No real account, export or deletion claims.

## Visual system

Reuse CircleRoboto, Material 3 ColorScheme and Space tokens. New components centralize 8/12/16/24 radii, group-type icons, avatars, gradient illustration tiles, empty states and group headers. Family/friends use warm semantic tertiary accents; office/club use primary/secondary. No feature hex colors, remote fonts, real photos or arbitrary asset downloads. Reading width stays 720px; screens scroll, preserve large-text wrapping, and expose at least 48px controls. The original archive/college-only styling remains only in legacy screens/tests while the active app uses neutral copy.

## Delivery boundaries

Mock repositories filter reads and mutations by exact group membership. Parent administration never grants subgroup content access. Depth is capped at 10, subgroup creation requires direct-parent membership, and roles are attached to an exact group. Other membership workflows (approval, invitation consent, owner transfer, cascade departure, DM privacy) must be implemented and tested before those actions are exposed. No production auth/backend/OTP/media or chat delivery is introduced.

Preserve all pre-existing uncommitted changes. This increment owns new workspace/domain/presentation files, the clean default main entry point, and optional callbacks in the access components created in the previous increment. Leave user-edited README/AGENTS/design-system/platform files untouched.
