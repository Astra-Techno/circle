# Transactional notification worker — N1b

Source batch dated 26 October 2026. Queue capture and provider delivery remain **off by default**. No APK, hosted cron job, production fixture or real provider message is part of this checkpoint.

## Captured events

| Mutation | Opted-in recipients at commit | Category |
|---|---|---|
| New Memory | Other active exact-group members with a registered Android login session | memories |
| New comment | Memory owner, excluding the actor | replies_reactions |
| Reply | Memory owner and active parent-comment author, deduplicated and excluding the actor | replies_reactions |

Migration 010 adds a private outbox. Capture runs inside the mutation transaction and snapshots eligible recipient/device/session references using one SQL fanout without a member-count cap. Both global/category preferences must already be enabled. Recipients who join, register or opt in later do not get retroactive capture. Rollback removes both the mutation and its queued rows; provider calls never run in HTTP mutations. The existing Memory/comment success responses are unchanged. Invalid mutations produce no event. Reactions and group/invitation actions are still future hooks; they are not claimed complete.

Each committed event/device pair has a unique key. Rows store references, lifecycle state and bounded operational reason codes, never private post/comment text, names, device tokens or bearer credentials. Memory and comment creation HTTP requests still lack general idempotency: a client that creates two Memories creates two distinct events. Queue deduplication does not change that API behavior.

## Delivery and failure handling

The CLI worker handles 1–100 rows per invocation (default 50), stops starting new work after 45 seconds, and uses a database-scoped MySQL advisory lock to prevent overlapping workers. Recovery/expiry sweeps each affect at most 1,000 rows per invocation. A five-minute lease recovers interrupted attempts after the old connection releases its lock. Attempts persist before network I/O; interrupted attempts consume retry budget.

Before each provider call it rechecks the captured device's account/session, open refresh session, Android platform, current active exact membership, opt-in category/global settings, and active target Memory/comment. Deleted content, logout, reassignment and lost access cancel pending delivery. iOS is excluded until its native configuration/delivery work is implemented. These checks cannot revoke a message already handed to the provider; client checks remain mandatory.

Quiet-hour events stay pending until the first allowed absolute minute, including repeated/skipped DST hours. Deferral does not consume an attempt. Events expire after 24 hours. Transient failures use bounded exponential backoff, honor Retry-After, and stop after six attempts. An unchanged successful device row is never re-sent merely because another device failed. Permanent provider rejection ends that row without deleting a token. Only structured FCM UNREGISTERED removes a token, with account/session predicates to preserve concurrent reassignment.

`sent` means provider acceptance, not device receipt, display or reading. A provider may accept a request whose response is lost, or a process may die before persisting success. Delivery therefore remains **at least once**, not exactly once. Stable event IDs support client deduplication; no duplicate-free device claim is made.

## Provider and future client contract

OpenAPI 0.3.5 defines PushMemoryEnvelope. The worker sends data-only references with canonical HTTPS API base URL, recipient id, SHA-256 session scope, stable event id, supported type, group/Memory/comment ids and expiry. It sends no title/body, public media URL, bearer token or arbitrary navigation route. FCM TTL is capped by remaining event lifetime. Android normal priority is deliberate for these Memory updates; background/terminated delivery and visible presentation still require device validation.

Before displaying, fetching or navigating, the client must match the configured trusted API base URL and active recipient/session, validate supported fields and expiry, then deduplicate on **trusted API URL + recipient + session_scope + event_id**. IDs can recur across recipients/deployments. Never send credentials to an incoming payload's URL. Fetch through the existing authorized API; handle removed/inaccessible content calmly. These client behaviors are the next implementation step, not something this worker establishes.

FCM transport is injectable for fictional provider tests. Real sending requires curl/OpenSSL, a valid project and private service-account file with the standard Google OAuth token endpoint. OAuth/provider response payloads and tokens are never logged. Operational worker output is aggregate counters only; failures return a nonzero exit code. The old direct user-send shortcut has been replaced by the queue/transport path.

## Hosting configuration — leave disabled until acceptance passes

The template documents:

```dotenv
PUSH_QUEUE_ENABLED=false
PUSH_DELIVERY_ENABLED=false
PUSH_API_BASE_URL=https://circle.cloudkart24.com/api/v1
FCM_PROJECT_ID=
FCM_SERVICE_ACCOUNT_PATH=
```

Keep the credential JSON outside the web root and source control. Confirm the hosting CLI runs PHP 8.3+ with curl/OpenSSL and the deployed database has migration 010. Confirm scheduler permissions, private logging/monitoring, queue terminal-state retention/cleanup and the correct project/API configuration. No private credentials are included here. Existing hosted .env is preserved by deployment, so absent switches remain off.

The private CLI command is:

```sh
composer notifications:work -- --limit=50
```

A hosting cron can invoke that command approximately once per minute from the private backend directory after device/client acceptance and explicit enablement. This document does not install cron or enable delivery. The entry script refuses web execution. A disabled run does not contact the database/provider. Missing configuration leaves rows untouched; inspect aggregate counters and private hosting configuration. Failed/dead rows are not automatically revived; an operational retry/retention policy remains tracked before broad rollout.

## Validation

Focused queue/policy suite: 24 tests / 573 assertions passed on dedicated circle_test. Includes transaction rollback, actor exclusion, comment/reply recipients, event/device deduplication, minimal scoped envelopes, quiet-hour/DST scheduling, retry timing and ceiling, crash leases, deleted content/preferences/membership, logout and token reassignment, conditional invalid-token cleanup, separate-device progress, batch limits, concurrent-worker exclusion, transport exceptions, platform gating and provider HTTP classification.

PHPStan and Composer validation pass. OpenAPI YAML parses; all 306 references resolve. JSON Schema accepts the minimal envelope fixture and rejects private-text additions, numeric ids and unsupported types. A focused independent static review found no blocking issue; it highlighted the scoped deduplication requirement now in the contract. Full backend: 159 tests / 2,673 assertions passed on circle_test. Flutter format/analyze and 11 server-mode regression checks pass; these mocks do not test the worker. Flutter source is unchanged; the 13 historical Windows-baseline comparisons remain unresolved and were not regenerated. Current handoff is in PROJECT_STATE.md. Provider tests use a fake transport; they do not establish Firebase delivery or native behavior.

Client scope validation, persistent foreground acceptance history and SDK lifecycle are now implemented in [N1c1](push-client-lifecycle.md). Opt-in UI, authorized presentation/taps and background/native acceptance are still unfinished; leave both backend switches off.
