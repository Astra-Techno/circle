# Phase 1

## Navigation and feed reliability increment

- Resume protected in-app post/group/album/member/event routes after mock invitation entry; reject external, unknown and looping return URLs.
- Clear return navigation when ending the demo, so the next entry opens a fresh feed.
- Build feed cards on demand with stable IDs; verify scrolling to the hundredth post and opening its detail.
- Expand regression coverage to 41 tests while retaining all 10 existing golden baselines.
- Align guidance and CI with direct, validated main-only commits and pushes; no feature branches or pull requests.

## Initial prototype

- Original light/dark semantic theme and reusable archive/card/notice layout.
- Explicit mock invitation guard and fictional, community-scoped repositories.
- Chronological feed, create post, comments, reaction/save toggles; all persist within the demo session.
- Groups, albums, searchable directory, profiles, reunion RSVP and appearance controls.
- Tests and Windows Flutter CI; no backend, real authentication or media delivery.
