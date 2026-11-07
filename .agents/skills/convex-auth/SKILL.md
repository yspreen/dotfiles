---
name: convex-auth
description: "Add Convex auth foundation and providers. Not authz audits or login UI-only edits."
---

<!-- Upstream-generated skill, locally narrowed. -->

# Add sign-in to the app

Install or extend `@convex-dev/auth` without replacing the app's existing auth model.

## Workflow

1. Read existing `convex/auth.ts`, `convex/auth.config.ts`, providers, client wrapper, and account schema.
2. Pin installed Convex and auth package versions. Use `convex-docs` when installed exports and types do not answer the question.
3. Keep the current provider unless the user requests a different sign-in method. Do not default to passkeys, passwords, or OAuth.
4. Use the package's current setup path for those versions. Install packages with Bun.
5. Use `convex-env` and `convex-deploy-guard` before changing deployment secrets. New setup needs `JWT_PRIVATE_KEY`, `JWKS`, `SITE_URL`. Generate keys headlessly with `jose`, never the interactive `bunx @convex-dev/auth` wizard (hangs without a TTY):
   `node -e 'import("jose").then(async({generateKeyPair,exportPKCS8,exportJWK})=>{const k=await generateKeyPair("RS256",{extractable:true});const priv=await exportPKCS8(k.privateKey);const pub=await exportJWK(k.publicKey);process.stdout.write(JSON.stringify({JWT_PRIVATE_KEY:priv.trimEnd().replace(/\n/g," "),JWKS:JSON.stringify({keys:[{use:"sig",...pub}]})}))})' > .auth-keys.json`
   Set each via the Convex MCP `envSet` tool, or CLI `bunx convex env set "JWT_PRIVATE_KEY=$JWT"`. Never `env set JWT_PRIVATE_KEY "$JWT"`: the leading `-----BEGIN` parses as a flag. Delete `.auth-keys.json` after.
6. Wire the platform-appropriate client provider and requested UI. Do not introduce web-only UI libraries into Expo. On web, add any imported shadcn/ui primitive first (`bunx shadcn@latest add <name>`); a missing `@/components/ui/*` breaks the build.
7. Verify one real sign-in, session restoration after reload, sign-out, and one protected server call.

## Rules

- Authentication proves identity. Use `convex-authz` for ownership and access-control audits.
- Do not replace working auth, rotate secrets, or change providers as incidental cleanup.
- Never print, commit, or leave generated keys in the worktree.
- Installed exports and types outrank bundled examples. Current official docs are next.
- A missing or wrong `convex/auth.config.ts` leaves users silently signed out with no error. Always check it.
- Successful typecheck is not sign-in proof. Exercise the configured provider and a protected function.
