#!/usr/bin/env bun
// Local AgentCard MCP server (stdio, newline-delimited JSON-RPC). Copies the card in ~/dotfiles/secrets/card.json into /tmp/tempagentcards/<handle>/<n>.json.

const handleArg = { handle: { type: "string", description: "Agent handle the cards belong to" } };

const tools = [
  {
    name: "create_agent_handle",
    description: "Create an agent handle. Cards belong to a handle.",
    inputSchema: { type: "object", properties: { name: { type: "string", description: "Handle name, e.g. claude-shopper" } }, required: ["name"] },
  },
  {
    name: "list_cards",
    description: "List all cards for an agent handle with their index, limits and expirations. No card numbers.",
    inputSchema: { type: "object", properties: handleArg, required: ["handle"] },
  },
  {
    name: "get_card_details",
    description: "Get full card details (number, expiry, CVC, billing address) for one card of an agent handle.",
    inputSchema: {
      type: "object",
      properties: { ...handleArg, card: { type: "integer", description: "Card index from list_cards" } },
      required: ["handle", "card"],
    },
  },
  {
    name: "create_card",
    description: "Create a virtual card for an agent handle. All constraints optional.",
    inputSchema: {
      type: "object",
      properties: {
        ...handleArg,
        monthly_limit_usd: { type: "number", description: "Monthly spend limit in USD" },
        max_uses: { type: "integer", description: "Card expires after this many uses" },
        expires_at: { type: "string", description: "Card expires after this UTC ISO 8601 date, e.g. 2026-12-31T23:59:59Z" },
      },
      required: ["handle"],
    },
  },
];

import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";

const SOURCE = `${process.env.HOME}/dotfiles/secrets/card.json`;
const ROOT = "/tmp/tempagentcards";

function dir(handle: string) {
  if (!/^[\w-]+$/.test(handle)) throw new Error("handle may only contain letters, digits, _ and -");
  const d = `${ROOT}/${handle}`;
  mkdirSync(d, { recursive: true });
  return d;
}

const indexes = (handle: string) =>
  readdirSync(dir(handle)).map((f) => /^(\d+)\.json$/.exec(f)?.[1]).filter(Boolean).map(Number).sort((a, b) => a - b);

function getCard(handle: string, n: unknown) {
  if (!indexes(handle).includes(Number(n))) throw new Error(`card ${n} not found for handle ${handle}`);
  return JSON.parse(readFileSync(`${dir(handle)}/${Number(n)}.json`, "utf8"));
}

// card file = secret card fields + meta; list/create only expose meta
const meta = ({ card, handle, monthly_limit_usd, max_uses, uses, expires_at, status, created_at }: any) =>
  ({ card, handle, monthly_limit_usd, max_uses, uses, expires_at, status, created_at });

function createCard(handle: string, a: Record<string, unknown>) {
  const card = {
    ...JSON.parse(readFileSync(SOURCE, "utf8")),
    card: (indexes(handle).at(-1) ?? 0) + 1,
    handle,
    monthly_limit_usd: a.monthly_limit_usd ?? null,
    max_uses: a.max_uses ?? null,
    uses: 0,
    expires_at: a.expires_at ?? null,
    status: "active",
    created_at: new Date().toISOString(),
  };
  writeFileSync(`${dir(handle)}/${card.card}.json`, JSON.stringify(card, null, 2), { mode: 0o600 });
  return meta(card);
}

function call(name: string, a: Record<string, any>) {
  if (name !== "create_agent_handle" && !a.handle) throw new Error("handle is required");
  switch (name) {
    case "create_agent_handle":
      if (!a.name) throw new Error("name is required");
      dir(a.name);
      return { handle: a.name, created_at: new Date().toISOString() };
    case "list_cards":
      return { handle: a.handle, cards: indexes(a.handle).map((n) => meta(getCard(a.handle, n))) };
    case "get_card_details":
      return getCard(a.handle, a.card);
    case "create_card":
      for (const k of ["monthly_limit_usd", "max_uses"]) if (a[k] !== undefined) a[k] = Number(a[k]); // inspector sends strings
      if (a.max_uses !== undefined && !(Number.isInteger(a.max_uses) && a.max_uses > 0)) throw new Error("max_uses must be a positive integer");
      if (a.monthly_limit_usd !== undefined && !(a.monthly_limit_usd > 0)) throw new Error("monthly_limit_usd must be positive");
      if (a.expires_at !== undefined && (!/Z$|[+-]00:?00$/.test(a.expires_at) || isNaN(Date.parse(a.expires_at)))) throw new Error("expires_at must be a UTC ISO 8601 date");
      return createCard(a.handle, a);
  }
  throw new Error(`Unknown tool: ${name}`);
}

function handle(msg: any) {
  switch (msg.method) {
    case "initialize":
      return { protocolVersion: msg.params?.protocolVersion ?? "2025-06-18", capabilities: { tools: {} }, serverInfo: { name: "agentcard-local", version: "0.0.1" } };
    case "ping":
      return {};
    case "tools/list":
      return { tools };
    case "tools/call":
      try {
        return { content: [{ type: "text", text: JSON.stringify(call(msg.params.name, msg.params.arguments ?? {}), null, 2) }] };
      } catch (e) {
        return { content: [{ type: "text", text: (e as Error).message }], isError: true };
      }
  }
  throw { code: -32601, message: `Method not found: ${msg.method}` };
}

let buf = "";
for await (const chunk of Bun.stdin.stream()) {
  buf += new TextDecoder().decode(chunk);
  let i;
  while ((i = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, i).trim();
    buf = buf.slice(i + 1);
    if (!line) continue;
    const msg = JSON.parse(line);
    if (msg.id === undefined) continue; // notification
    let reply;
    try {
      reply = { jsonrpc: "2.0", id: msg.id, result: handle(msg) };
    } catch (error) {
      reply = { jsonrpc: "2.0", id: msg.id, error };
    }
    process.stdout.write(JSON.stringify(reply) + "\n");
  }
}
