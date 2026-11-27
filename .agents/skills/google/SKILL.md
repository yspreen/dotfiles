---
name: google
description: Use when the user says Google
---

do all research in google in netscape.
a google search does not end with the result page. reading the ai overview and the page summaries is useful but it's just the start.
click the results, read the found page yourself. the results overview list in google alone is insufficient.
load the netscape skill. It should be dynamically injected here for your convenience:

<netscapeInjected>
!`awk 'f>=2; /^---$/{f++}' ~/.claude/skills/netscape/SKILL.md`
</netscapeInjected>
