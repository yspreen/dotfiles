---
name: sentry
description: Fix the latest sentry issue for this project.
---

# Step 1

Run the command `sentry-latest`
It will either produce the latest issue in markdown format, or this error message:

```
> sentry-latest
No project is configured for this working directory.
To configure for this path, rerun with:

sentry-latest --set-project=<project>

Where project is one of:
 ... list of projects
```

If you get that error, use the path you're in to call `sentry-latest --set-project=some-project-from-above`

# Step 2

Once you have the issue, fix it.

# Step 3

Finally make a commit with your changes mentioning the issue by name and writing a helpful commit message.
