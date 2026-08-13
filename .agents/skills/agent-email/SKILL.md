---
name: agent-email
description: Get your own email address to receive emails from. This is your inbox. Not the user's inbox. Use gmail to read the users emails
---

## Commands

### Create inbox

```bash
bun ~/dotfiles/scripts/mailtm.ts
```

Stdout: `<n> <email>` e.g. `1 c26836c9-…@emalupe.com`

Remember `n` for later reads. It's your inbox number.

### Read latest email of your inbox

```bash
bun ~/dotfiles/scripts/mailtm.ts <n>
```

Where <n> is your inbox.

Stdout:

- `empty` if no messages
- else line 1 = subject, rest = plain text body (falls back to html/intro)

### Read more emails

```bash
bun ~/dotfiles/scripts/mailtm.ts <n> <i>
```

start with 2 for the second most recent email. Then go up: 3, 4, ...

### Counts

```bash
bun ~/dotfiles/scripts/mailtm.ts <n> count   # messages in inbox n
bun ~/dotfiles/scripts/mailtm.ts count       # number of inboxes on this machine
```
