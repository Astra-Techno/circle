# ADR 0004: group-scoped events and polls

Status: accepted by the owner, 22 Oct 2026.

## Decision

- **Events:** any member can create an event, but only inside a group they belong to. Visibility and RSVP are limited to that group's members. A group's admins may restrict creation to admins.
- Events support types (function, wedding, reunion, meetup, birthday, trip, online, other), time zones, venue or online link, RSVP Going/Maybe/Not going with **guest count**, reminders, a discussion thread and an event album.
- **Polls** can live in Memories, group chat, 1:1 chat and events. They support single/multiple choice, anonymous or named votes, an end time, member-added options and results visibility. A **date poll** variant helps pick event dates.
- Both arrive in M5 together with push notifications. UI-4 builds them with mocks.

## Context

Families and batches organize functions, weddings and reunions. The owner wants one event and poll system for every group type. Guest counts matter for family functions.

## Alternatives

- Admin-only event creation: less noise, but slower for informal groups.
- Cross-group events: convenient, but they blur group privacy boundaries. Rejected for now.
- Payments/contributions for events: out of MVP scope (README §3.9).

## Consequences

- Poll is a shared entity with a polymorphic context (`memory`, `message`, `event`).
- Reminders need scheduled jobs and FCM.
- Event photos link into albums, so the M4 media work must support event albums.
