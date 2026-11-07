---
name: convex-agent
description: "Add Convex Agent or RAG backend. Not UI or non-Convex AI."
---

<!-- GENERATED from convex-agents content/capabilities/agent.json — do not edit by hand. -->

# Add an AI agent / RAG backend

Install @convex-dev/agent for durable threads, message history, tool-calls, and vector search/RAG — the backend for an in-app AI agent.

## Workflow

1. Install @convex-dev/agent + @convex-dev/ai-sdk-provider; add the agent component to convex.config.ts.
2. Define the agent (tools, instructions) with `languageModel: convexGateway("provider/model")`. No LLM key needed (convex 1.45+, Convex Cloud paid plan). Free plan, self-hosted, or local backend: call the provider SDK with a key stored via `convex-env`.
3. Create threads + stream messages; persist history in Convex.
4. For RAG: embed docs into a vector index and retrieve in the tool. The gateway doesn't serve embeddings yet; store the embedding provider's key via `convex-env`.

## Rules

- Default to the Convex AI Gateway for model calls. Any provider key (embeddings, gateway fallback) lives in Convex env, never client-side.
- Run model calls in actions ('use node' if the SDK needs it).
- Persist threads/messages in Convex for durability + reactivity.
