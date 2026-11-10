# Public static-site emergency release and rollback plan

**Status:** Code-only draft. No chosen or verified production host/domain.

## What currently exists

A zero-cost generator supports:
- Draft preview (noindex)
- Owner-reviewed published export (indexable)
- Emergency stand-down artifact (--emergency-off): no editorial content,
  noindex, disallow-all robots, empty sitemap, plain 404
- None of these actions automatically publish, bill, delete data or modify
  the Flutter PWA or Supabase.

## Operator release actions (host adapter to be chosen)

Before the FIRST public launch, choose and verify a hosting provider and a
domain. Implement and rehearse, without touching live learners:

1. A two-person or separately authenticated owner-approved release step to
   promote a reviewed immutable build artifact to a pinned target.
2. Instant platform-side disable or the closest documented provider-supported
   stop: pause serving the public site, force a maintenance/503 response,
   or atomically swap to the emergency artifact. No source rebuild required.
3. Confirm removed content does not remain reachable through old static paths,
   redirects, edge caches, service workers or alternate hostnames.
4. Purge affected CDN caches where supported; document TTL and residual
   propagation limits rather than promising immediate universal removal.
5. For temporary outage use HTTP 503 + Retry-After where the host supports it;
   removed permanent paths need real 404/410. A static emergency HTML page
   by itself cannot enforce those HTTP status codes.
6. Restore a pinned previously reviewed build; confirm 200 only for published
   content, 404/410 for unpublished URLs, matching canonical and sitemap URLs.
7. Record operator, time, reason, released artifact ID, rollback evidence and
   affected routes. Keep existing Flutter Learn/Library/Progress, TEL Fast,
   BYOK hard-disable and protected data unchanged.

## Go/no-go

No real public site publication or DNS/hosting mutation until the host-level
emergency shutdown is tested and the owner has approved canonical domain,
editorial content, privacy boundaries and any possible subscription charge.

The app's current Feature Control Center does not yet govern the static host.
Never imply a planned database flag will instantly disable independently
hosted cached HTML.
