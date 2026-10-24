# ADR 0002: any-community scope with nested groups and per-group membership

Status: accepted by the owner, 22 Oct 2026.

## Decision

CIRCLE serves any private group (family, friends, school, college, office, club, other), not a single college community.
- Any user creates a root group and becomes its **owner** and admin.
- Any member can create a **subgroup**, recursively, up to **10 levels**.
- Every group and subgroup has identical rules: owner/admin/member roles, direct add (with the invitee's consent) or invite link, a per-group approval setting, and invite links with expiry, usage limit and reset.
- To join a subgroup you must already be a member of its direct parent.
- Each subgroup is **listed** or **hidden**.
- Parent admins **cannot read** subgroup content and can only remove a reported subgroup.
- Leaving or being removed from a group **cascades** to all descendants.
- The last admin cannot leave; the owner cannot be removed by other admins and can transfer ownership.

## Context

The owner wants one app for all their circles. Their real example is AKCE 2009 → departments → CSE sections → friend gangs. The original README assumed one pre-provisioned college community, so its single-tenant `community_id` model no longer fits.

## Alternatives

- **Single level of subgroups:** simpler permissions and navigation, but it can't represent the owner's real structures.
- **Unlimited depth:** unbounded queries and confusing navigation; 10 levels covers real needs.
- **Inherited access (parent admins see everything):** simpler moderation, but it breaks the privacy promise for subgroups such as "Cousins" or a friend gang.

## Consequences

- Authorization checks active membership in the **exact** group; nothing is inherited.
- MySQL stores `parent_id`, `root_id`, `depth` and a `group_closure` table for subtree queries, depth checks and transactional cascade removal.
- The UI needs a group tree, tappable breadcrumbs, recent/pinned groups and an audience picker everywhere content is created.
- Moderating hidden or private subgroups relies on reports and removal without reading content.
- The Phase 1 prototype (single community, `CIRCLE-DEMO`) must be reworked (README §4.6 UI-1/UI-2).
