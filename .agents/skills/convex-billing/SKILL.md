---
name: convex-billing
description: "Add Stripe via @convex-dev/stripe. Not other providers, pricing, or billing UI-only edits."
---

<!-- Upstream-generated skill, locally narrowed. -->

# Add billing / payments

Wire Stripe through `@convex-dev/stripe` for an existing Convex app.

## Workflow

1. Pin installed Convex and Stripe component versions. Read installed exports and the current official component README.
2. Confirm product mode, price IDs, customer identity key, entitlement rules, redirects or deep links, and target deployment.
3. Install with Bun and register the component using its current documented export.
4. Add checkout and webhook wiring through app-side Convex functions. Keep webhook verification in the component.
5. Store Stripe secrets with `convex-env`; use `convex-deploy-guard` for deployment changes.
6. Gate paid behavior from server-owned subscription state. Never trust client claims.
7. Test checkout and webhook handling with Stripe test mode. Verify active, trialing, canceled, failed-payment, duplicate-event, and unauthenticated cases.

## Rules

- Do not copy version-specific imports from this skill. Verify installed exports first.
- Never use live Stripe keys or create live charges during verification without explicit authorization.
- Keep secrets in Convex deployment env. Never expose them through client env or logs.
- Make webhook processing idempotent. Treat redirects as UX, not payment proof.
- Use `convex-authz` if entitlement reads can cross account boundaries.
