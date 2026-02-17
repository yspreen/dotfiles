---
name: searxng
description: Deep web search using the local SearXNG metasearch instance. Use when you need to research a topic, find documentation, look up current events, or gather information from the web.
---

# SearXNG Web Search

Use this skill to perform web searches via the local SearXNG instance at `http://localhost:8888`.

## How to search

```bash
curl -s 'http://localhost:8888/search?q=QUERY&format=json' | python3 -c "
import sys, json
d = json.load(sys.stdin)
for r in d.get('results', [])[:10]:
    print(r.get('title', ''))
    print(r.get('url', ''))
    print(r.get('content', ''))
    print('---')
for a in d.get('answers', []):
    print('ANSWER:', a)
"
```

Always URL-encode the query (use `+` for spaces, `%26` for `&`, etc.).

## Parameters

| Parameter    | Values                                           | Notes                              |
|------------- |------------------------------------------------- |----------------------------------- |
| `q`          | search query (required)                          | URL-encoded                        |
| `format`     | `json`                                           | Always use `json`                  |
| `categories` | `general`, `images`, `videos`, `news`, `music`, `it`, `science`, `files`, `social media` | Comma-separated; default: general  |
| `engines`    | engine names                                     | Comma-separated; overrides categories |
| `language`   | `en`, `de`, `fr`, `auto`, ...                    | Default: auto                      |
| `time_range` | `day`, `week`, `month`, `year`                   | Filter by recency                  |
| `pageno`     | integer (1, 2, 3, ...)                           | Pagination                         |
| `safesearch` | `0` (off), `1` (moderate), `2` (strict)          | Default: 0                         |

## Result fields

Each result object contains:

- `title` — page title
- `url` — link
- `content` — snippet/description
- `engine` / `engines` — source engine(s)
- `score` — relevance score (higher = better)
- `category` — result category
- `publishedDate` — when available (especially news)
- `thumbnail` / `img_src` — image URLs (image results)
- `resolution`, `img_format`, `filesize` — image metadata (image results)

Top-level response also contains `answers`, `suggestions`, `corrections`, and `infoboxes`.

## Strategy

1. **Start broad.** Run a general search first. Use 10-15 results to get an overview.
2. **Narrow with categories.** Use `categories=it` for programming, `categories=news` for current events, `categories=science` for papers.
3. **Narrow with time_range.** Use `time_range=year` or `time_range=month` for recent info.
4. **Paginate.** Use `pageno=2`, `pageno=3` etc. to go deeper.
5. **Read promising URLs.** After finding relevant results, use `curl` to fetch full page content for deeper analysis.
6. **Iterate.** Refine the query based on what you learn. Use terms and phrases found in good results.

## Examples

General search:
```bash
curl -s 'http://localhost:8888/search?q=rust+async+runtime+comparison&format=json&categories=general'
```

Recent news:
```bash
curl -s 'http://localhost:8888/search?q=apple+wwdc+2026&format=json&categories=news&time_range=month'
```

Programming/IT:
```bash
curl -s 'http://localhost:8888/search?q=python+dataclass+frozen&format=json&categories=it'
```

Page 2 of results:
```bash
curl -s 'http://localhost:8888/search?q=kubernetes+networking&format=json&pageno=2'
```

## Tips

- SearXNG aggregates across many engines (Google, Brave, DuckDuckGo, Startpage, StackOverflow, Wikipedia, etc.). Results with multiple `engines` and high `score` are usually the most relevant.
- Use `answers` and `infoboxes` from the response — they often contain direct answers.
- For programming questions, `categories=it` searches StackOverflow, GitHub, and other dev sources directly.
- If the query returns few results, simplify it or try different keywords.
