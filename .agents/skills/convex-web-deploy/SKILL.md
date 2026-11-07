---
name: convex-web-deploy
description: Deploy a project's Convex production backend together with its web surfaces (website, Expo web app) to Cloudflare. Use when asked to deploy Convex and web.
---

# Convex + Web Deploy

Run from repo root. Read project docs (`AGENTS.md`, `package.json` scripts, `wrangler.jsonc`) first for the build script, deployment name, domains, and scripts to avoid.

## Deploy

1. `git status --short`. Preserve unrelated changes.

2. Deploy Convex production (follow `convex-deploy-guard`):

```sh
bunx convex deploy --yes
```

Require output naming the expected prod deployment (`<name>.convex.cloud`) and successful finalization.

3. Build web with the project's script (e.g. `bun run web-build`). If one build emits both website (`/`) and Expo web app (`/app/`), deploy that combined output only, never a sub-`dist` alone.

4. Deploy to Cloudflare:

```sh
if [ -f .env.cloudflare.local ]; then set -a; source .env.cloudflare.local; set +a; fi
bunx wrangler deploy
```

Record the Worker version ID.

## Pitfalls

- `bunx convex deploy` targets prod automatically. No env override.
- Never run env-sync scripts (dev → prod) or all-in-one deploy scripts unless asked. They overwrite prod values or deploy extra services.
- Build scripts that temporarily edit `app.json` or config must restore it, even on failure. Check `git status` after.
- Missing `SENTRY_AUTH_TOKEN` only skips source-map upload.
- Lint warnings are nonfatal; build or type errors are fatal.
- Wrangler needs Cloudflare auth: existing login or `.env.cloudflare.local` (`CLOUDFLARE_ACCOUNT_ID`).
- Use bun/bunx. Never npm, pnpm, or npx.

## Smoke test

`curl -L -sS -o /dev/null -w '%{http_code}'` the Convex URL, each custom domain `/` and `/app/`, and the `workers.dev` equivalents. Require all `200`.

Then `git status --short`: clean unless changes existed before. Report Convex URL, website URL, web-app URL, Worker version ID, warnings, skipped Sentry upload, final tree state.
