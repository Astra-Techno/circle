# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

Small intimate groups of 5-30 people: families, close friend circles, small office teams, college friend groups, apartment neighbours, and hobby clubs. Primarily Indian users (English language, Indian mobile numbers). The typical user juggles WhatsApp groups, shared Google Photos albums, Facebook groups, and a calendar app to stay connected with their real-life circles. They want one private place that does it all without the noise.

## Product Purpose

Circle is a private social app for real-life groups. It replaces five fragmented tools (WhatsApp for chat, Facebook for posts, Google Photos for shared albums, Google Calendar for events, and various poll apps) with one focused, ad-free space. Success means a family or friend group moves their shared life into Circle and keeps coming back to post memories, plan events, chat, and vote on decisions together.

## Positioning

1. **Privacy-first**: No ads, no algorithm, no data selling. Your group, your rules, your data. Every feature is scoped to exact group membership, never leaked across groups.
2. **All-in-one group hub**: Memories (photos + captions), live chat, events with RSVP, polls, albums, and time capsules in one app per group.
3. **Nested group structure**: Groups within groups up to 10 levels deep (Family > Siblings > Mumbai Cousins) with proper roles, permissions, and approval flows. No other consumer social app does this.
4. **Memory preservation**: Not a disappearing chat stream. Memories are a growing shared archive that matters more over years, not less.

## Operating Context

- Used on personal phones (primarily Android in India, some iOS) during daily life moments: sharing a meal photo, planning a weekend trek, voting on a restaurant, RSVPing to a birthday.
- Groups are created by one person who invites others via shareable links. New members need approval in private groups.
- Content is photos-first: the camera/gallery is the primary composer entry point. Text-only memories are supported but secondary.
- Offline tolerance matters: Indian mobile networks are unreliable. The app should handle poor connectivity gracefully.

## Capabilities and Constraints

**Live features**: Authentication (mobile + password), nested groups (create, join, invite, roles, tree), Memories (post, react, comment, save, delete), live chat (1:1 and group, photos), Events (create, RSVP, attendees), Polls (create, vote, results), Capsules (time-locked group memories), Albums (photo collections), Search, Activity inbox, push notifications (iOS confirmed, Android in progress).

**Constraints**: No public/discover mode; all content is private to group members. No video upload. No stories/disappearing content. Access is per exact group, never inherited from parent or child groups. The post stream is called "Memories", never "feed". Registration requires mobile number + password; OTP authentication planned but not yet implemented.

**Undecided**: Offline-first sync strategy, end-to-end encryption scope, monetisation model.

## Brand Commitments

- **Name**: Circle
- **Voice**: Warm, calm, honest. No startup jargon, no engagement tricks, no dark patterns. The app speaks like a thoughtful friend, not a platform.
- **Typography**: Native Apple system text on iOS/macOS; bundled Inter (400/500/600) on Android. Previously CircleRoboto, migrated to platform-native.
- **Design direction**: Editorial, photo-first. Photos carry the colour; chrome is quiet. Social 2.6 coloured icon tiles. 8-point spacing grid, semantic colour tokens, 48px minimum touch targets.
- **Logo**: "Circle" wordmark, 32px in header.

## Evidence on Hand

- Working Flutter prototype with 27+ source files, full design system, and test suite (800+ tests).
- 25 AI test personas registered against production API across 5 realistic Indian groups.
- Production backend (PHP 8.3, MySQL) with authenticated API serving all core features.
- Signed Android APK and iOS TestFlight builds published.
- No real user data, testimonials, or usage metrics yet. All demo content is fictional and lives only in tests.

## Product Principles

1. **Privacy is the product**: Every architectural decision defaults to private. No public profiles, no discoverability, no cross-group data leakage.
2. **One app, not five**: Each feature (chat, events, polls, albums) must feel native within the group context, not bolted on.
3. **Memories over messages**: The timeline is an archive worth revisiting. Photo quality, presentation, and organisation matter more than speed.
4. **Calm over engagement**: No read receipts pressure, no typing indicators, no algorithmic sorting, no notification spam. Respect attention.
5. **Small groups, deep bonds**: Optimised for 5-30 people who know each other in real life. Features that only matter at scale (moderation queues, content algorithms) are deprioritised.

## Accessibility & Inclusion

- 48px minimum touch targets enforced by design system guard tests.
- Semantic colour tokens with light/dark mode; WCAG AA contrast targets.
- Large text support (scales to 200% with layout adaptation at 140% threshold).
- Screen reader labels on all interactive elements (tooltips on icon-only dock).
- Indian mobile context: works on budget Android devices, handles variable network quality.
