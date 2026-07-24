---
name: preferred-websearch
description: The entry point for any web search. Whenever the user tells you to look up anything on the internet, start here. All other web-related skills are delegated to by this skill.
---

There are 4 ways you can search something:
1. direct web search
2. google inside chrome skill
3. searxng + webreading
4. google inside browser skill

Unfortunately the browser skill is completely useless for google because we don't have remote browser access and google has a captcha. it's good for headless navigation on no-captcha websites though.
chrome is the most robust but the slowest.
searxng is powerful and fast but flakey, sometimes it gets blocked by google for a few days.
direct web search is fast but prone to websites blocking AI agents.
the webreading skill is fast, efficient, never blocks AI agents, but rate limits us and can stop working for hours at a time.

Choose the right tool for each query. Direct web search should never be the only source, but can be run in parallel with a searxng request in 2 parallel subagents. You can then read URLs with the webreading skill, and if that one ever fails, you can read search results with the browser. Once you run into the captcha, use chrome as the most powerful but slowest fallback alternative.
