---
name: searxng
description: Deep web search using the local SearXNG metasearch instance. Use when you need to research a topic, find documentation, look up current events, or gather information from the web.
---

# SearXNG Web Search

Use this skill to search with the local helper command:

```bash
search-internet "This is my search"
```

The command automatically:

1. Verifies Docker is running (tries `orp`, then `orb`, then opens OrbStack/Docker).
2. Ensures the SearXNG container is running from `~/Documents/proj/searxng` with:
   ```bash
   docker run --rm --name searxng -d \
       -p 8888:8080 \
       -v "./config/:/etc/searxng/" \
       -v "./data/:/var/cache/searxng/" \
       docker.io/searxng/searxng:latest
   ```
3. Runs a JSON search request against `http://localhost:8888/search`.
4. Keeps a 10-minute idle timeout that kills the `searxng` container if no new searches happen.

`search-internet` is provisioned by `/Users/user/dotfiles/scripts/post-activation.sh`.

## Usage notes

- Pass exactly one query argument (quote it).
- Output is raw JSON from SearXNG; use `jq` when you want filtered fields.
