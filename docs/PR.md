# CIRCLE Phase 1: local invitation-to-memory journey

Adds an Android-first Flutter prototype with fictional data, mock invitation access, feed/detail/comment creation and session-local reactions/saves. Supporting routes cover groups, albums, directory, reunions and profile with search, RSVP, theme choice and session reset.

Architecture uses Riverpod, go_router and injected domain repositories. No production backend, credentials or media uploads. Original design; provisional golden images live under mobile/test/goldens. See validation.md for actual checks and native device limitations.

Review focus: navigation coherence, state reset, responsive typography, privacy copy and golden screenshots. Real authorization, approval, media, moderation and persistent storage remain future milestones.
