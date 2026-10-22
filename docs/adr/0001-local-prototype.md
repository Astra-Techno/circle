# ADR 0001: explicit local prototype boundary

Decision: use injected in-memory repositories, a visible mock invitation and no network client for Phase 1.

Context: the first milestone must demonstrate a coherent mobile journey without a production backend or real classmates' data.

Alternatives: fake production login would misrepresent security; a real PHP API would exceed scope and precede a reviewed OpenAPI contract.

Consequences: state survives navigation but not process restart; all access checks are local demonstration checks. Production authentication, tenant/group authorization, persistence, media and moderation require separate implementation and security tests before launch. Dio remains deferred until network integration.
