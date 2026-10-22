# Phase 1 architecture

Flutter stable, Riverpod dependency injection and async controllers, go_router guarded routes. Domain immutable entities and repository interfaces have no Flutter dependency. Data repositories contain fictional fixtures and session-local changes. Presentation uses shared components and semantic themes. Feed mutations are synchronous local operations after async loading; production write retries/idempotency are deferred until a contract exists.

Mock invitation access is deliberately not authentication. The route guard prevents accidental prototype navigation before entry; it is not an authorization boundary. Repository reads and mutations require a community scope and deny unknown tenants. Group visibility is limited to the single fictional member's groups. Production must enforce both on the server.

No network requests exist in Phase 1; Dio is deferred until networking is needed. No tokens, passwords, real user data, media uploads, or telemetry. State resets on process restart or ending the session. Backend remains untouched.

Navigation return policy lives in app/route_policy.dart, separate from widgets. Protected in-app destinations are encoded into the invitation URL and resumed after mock entry. Only known relative app routes are accepted; unknown/external destinations fall back to the feed. Ending a session resets navigation to a fresh invitation with no return URL. This does not implement native OS app links or production authorization.

The feed uses ListView.builder with stable post keys and an index callback, creating cards on demand while preserving identity when new posts prepend. Data remains a session-local list; real cursor pagination is deferred until the API contract exists.
