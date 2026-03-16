---
name: read-web
description: Read and extract content from web pages using Jina Reader API. Use when you need to fetch a URL's content as clean markdown for reading, summarizing, or extracting information from web pages.
---

# Read Web

Fetch any web page as clean, LLM-friendly markdown using the Jina Reader API.

## Usage

To read a web page, make an HTTP request to the Jina Reader API by prefixing the target URL with `https://r.jina.ai/`:

```bash
curl -s -H "Authorization: Bearer jina_6b9d86324cd44572946d3b25a0191dc1IbEg33fCQeQh0cPKUP34KPacG_Qp" \
     -H "Accept: text/markdown" \
     "https://r.jina.ai/https://example.com"
```

## Options

### Return format

By default, returns markdown. You can request other formats:

- **Markdown** (default): `-H "Accept: text/markdown"`
- **Plain text**: `-H "Accept: text/plain"`
- **HTML**: `-H "Accept: text/html"`

### Additional headers

- **No cache** (force fresh fetch): `-H "X-No-Cache: true"`
- **With links preserved**: `-H "X-With-Links: true"`
- **With images preserved**: `-H "X-With-Images: true"`
- **Target selector** (extract specific element): `-H "X-Target-Selector: article"`
- **Wait for selector** (dynamic pages): `-H "X-Wait-For-Selector: .content"`
- **Timeout** (ms): `-H "X-Timeout: 10000"`

## Examples

### Read a documentation page
```bash
curl -s -H "Authorization: Bearer jina_6b9d86324cd44572946d3b25a0191dc1IbEg33fCQeQh0cPKUP34KPacG_Qp" \
     -H "Accept: text/markdown" \
     "https://r.jina.ai/https://docs.example.com/getting-started"
```

### Extract just the article content
```bash
curl -s -H "Authorization: Bearer jina_6b9d86324cd44572946d3b25a0191dc1IbEg33fCQeQh0cPKUP34KPacG_Qp" \
     -H "Accept: text/markdown" \
     -H "X-Target-Selector: article" \
     "https://r.jina.ai/https://blog.example.com/post"
```

### Read a page with links preserved
```bash
curl -s -H "Authorization: Bearer jina_6b9d86324cd44572946d3b25a0191dc1IbEg33fCQeQh0cPKUP34KPacG_Qp" \
     -H "Accept: text/markdown" \
     -H "X-With-Links: true" \
     "https://r.jina.ai/https://example.com/resources"
```

## Notes

- The API converts JavaScript-rendered pages to clean text, so it works on SPAs and dynamic sites.
- For very large pages, consider using `X-Target-Selector` to extract only the relevant section.
- Rate limits apply per the Jina API plan associated with this token.
