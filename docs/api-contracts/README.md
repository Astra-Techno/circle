# Future API contracts

No API client or server is implemented. Before Phase 2, define docs/openapi.yaml for /api/v1: invitation/authentication, approval status, tenant membership, paginated feed, comments, reactions and saves. Specify stable typed errors, expiry/revocation, authorization, idempotency keys, rate limits and gated media. All community/group access must be checked server-side; client IDs grant no access. Implement Dio configuration only against that reviewed contract.
