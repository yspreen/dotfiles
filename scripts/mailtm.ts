#!/usr/bin/env bun
import { mkdir, readdir, readFile, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { randomUUID } from "node:crypto";

const API = "https://api.mail.tm";
const STORE = join(homedir(), "dotfiles/secrets/mailtm");

type Inbox = {
  email: string;
  password: string;
  bearer: string;
};

type Domain = {
  id: string;
  domain: string;
  isActive: boolean;
  isPrivate: boolean;
};

type TokenResponse = {
  token: string;
  id: string;
};

type MessageSummary = {
  id: string;
  subject?: string;
  intro?: string;
  createdAt?: string;
};

type Message = MessageSummary & {
  text?: string;
  html?: string[] | string;
  from?: { address?: string; name?: string };
  to?: { address?: string; name?: string }[];
};

type HydraCollection<T> = {
  "hydra:member"?: T[];
  "hydra:totalItems"?: number;
  member?: T[];
  totalItems?: number;
};

async function api<T>(
  path: string,
  init: RequestInit = {},
  bearer?: string,
): Promise<T> {
  const headers = new Headers(init.headers);
  if (!headers.has("Accept")) headers.set("Accept", "application/json");
  if (init.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  if (bearer) headers.set("Authorization", `Bearer ${bearer}`);

  const res = await fetch(`${API}${path}`, { ...init, headers });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    const err = new Error(`mail.tm ${init.method ?? "GET"} ${path} → ${res.status}: ${body}`) as Error & {
      status: number;
    };
    err.status = res.status;
    throw err;
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

function members<T>(col: HydraCollection<T> | T[]): T[] {
  if (Array.isArray(col)) return col;
  return col["hydra:member"] ?? col.member ?? [];
}

function totalItems<T>(col: HydraCollection<T> | T[]): number {
  if (Array.isArray(col)) return col.length;
  return col["hydra:totalItems"] ?? col.totalItems ?? members(col).length;
}

// --- API methods ---

export async function getDomains(): Promise<Domain[]> {
  const data = await api<HydraCollection<Domain> | Domain[]>("/domains");
  return members(data).filter((d) => d.isActive && !d.isPrivate);
}

export async function createAccount(
  address: string,
  password: string,
): Promise<{ id: string; address: string }> {
  return api("/accounts", {
    method: "POST",
    body: JSON.stringify({ address, password }),
  });
}

export async function getToken(
  address: string,
  password: string,
): Promise<TokenResponse> {
  return api("/token", {
    method: "POST",
    body: JSON.stringify({ address, password }),
  });
}

export async function getMessages(
  bearer: string,
  page = 1,
): Promise<HydraCollection<MessageSummary>> {
  return api(`/messages?page=${page}`, {}, bearer);
}

export async function getMessage(
  bearer: string,
  id: string,
): Promise<Message> {
  return api(`/messages/${id}`, {}, bearer);
}

export async function deleteMessage(
  bearer: string,
  id: string,
): Promise<void> {
  await api(`/messages/${id}`, { method: "DELETE" }, bearer);
}

export async function getMe(bearer: string): Promise<{ id: string; address: string }> {
  return api("/me", {}, bearer);
}

export async function deleteAccount(
  bearer: string,
  id: string,
): Promise<void> {
  await api(`/accounts/${id}`, { method: "DELETE" }, bearer);
}

// --- storage ---

async function ensureStore(): Promise<void> {
  await mkdir(STORE, { recursive: true });
}

async function listInboxIds(): Promise<number[]> {
  await ensureStore();
  const files = await readdir(STORE);
  return files
    .map((f) => {
      const m = /^(\d+)\.json$/.exec(f);
      return m ? Number(m[1]) : null;
    })
    .filter((n): n is number => n !== null)
    .sort((a, b) => a - b);
}

function inboxPath(id: number): string {
  return join(STORE, `${id}.json`);
}

async function readInbox(id: number): Promise<Inbox> {
  try {
    const raw = await readFile(inboxPath(id), "utf8");
    return JSON.parse(raw) as Inbox;
  } catch {
    throw new Error(`inbox ${id} not found`);
  }
}

async function writeInbox(id: number, inbox: Inbox): Promise<void> {
  await ensureStore();
  await writeFile(inboxPath(id), JSON.stringify(inbox, null, 2) + "\n", {
    mode: 0o600,
  });
}

async function nextInboxId(): Promise<number> {
  const ids = await listInboxIds();
  if (ids.length === 0) return 1;
  return Math.max(...ids) + 1;
}

async function withBearer<T>(
  id: number,
  fn: (bearer: string, inbox: Inbox) => Promise<T>,
): Promise<T> {
  const inbox = await readInbox(id);
  const tryOnce = async (bearer: string) => fn(bearer, inbox);

  try {
    if (inbox.bearer) {
      return await tryOnce(inbox.bearer);
    }
  } catch (e) {
    const status = (e as { status?: number }).status;
    if (status !== 401 && status !== 403) throw e;
  }

  const { token } = await getToken(inbox.email, inbox.password);
  inbox.bearer = token;
  await writeInbox(id, inbox);
  return tryOnce(token);
}

// --- commands ---

async function cmdCreate(): Promise<void> {
  const domains = await getDomains();
  if (domains.length === 0) throw new Error("no active domains");
  const domain = domains[0]!.domain;
  const local = randomUUID();
  const password = randomUUID();
  const email = `${local}@${domain}`;

  await createAccount(email, password);
  const { token } = await getToken(email, password);

  const id = await nextInboxId();
  await writeInbox(id, { email, password, bearer: token });
  console.log(`${id} ${email}`);
}

function messageBody(msg: Message): string {
  if (msg.text && msg.text.trim()) return msg.text.trimEnd();
  if (Array.isArray(msg.html)) return msg.html.join("\n").trimEnd();
  if (typeof msg.html === "string" && msg.html.trim()) return msg.html.trimEnd();
  if (msg.intro && msg.intro.trim()) return msg.intro.trimEnd();
  return "";
}

async function cmdRead(inboxId: number, index = 1): Promise<void> {
  if (index < 1) throw new Error("email index must be >= 1");

  await withBearer(inboxId, async (bearer) => {
    // mail.tm returns newest first
    const pageSize = 30;
    const page = Math.ceil(index / pageSize);
    const offset = (index - 1) % pageSize;

    const list = await getMessages(bearer, page);
    const items = members(list);
    if (items.length <= offset) {
      console.log("empty");
      return;
    }

    const summary = items[offset]!;
    const full = await getMessage(bearer, summary.id);
    const subject = full.subject ?? summary.subject ?? "";
    const content = messageBody(full);
    console.log(subject);
    console.log(content);
  });
}

async function cmdInboxCount(inboxId: number): Promise<void> {
  await withBearer(inboxId, async (bearer) => {
    const list = await getMessages(bearer, 1);
    console.log(String(totalItems(list)));
  });
}

async function cmdCountInboxes(): Promise<void> {
  const ids = await listInboxIds();
  console.log(String(ids.length));
}

function usage(): never {
  console.error(`usage:
  bun mailtm.ts              create inbox → "<n> <email>"
  bun mailtm.ts <n>          latest email subject + body (or empty)
  bun mailtm.ts <n> <i>      i-th most recent email (1 = latest)
  bun mailtm.ts <n> count    email count for inbox n
  bun mailtm.ts count        inbox count`);
  process.exit(2);
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    await cmdCreate();
    return;
  }

  if (args.length === 1 && args[0] === "count") {
    await cmdCountInboxes();
    return;
  }

  if (args.length === 1 && /^\d+$/.test(args[0]!)) {
    await cmdRead(Number(args[0]), 1);
    return;
  }

  if (args.length === 2 && /^\d+$/.test(args[0]!) && args[1] === "count") {
    await cmdInboxCount(Number(args[0]));
    return;
  }

  if (args.length === 2 && /^\d+$/.test(args[0]!) && /^\d+$/.test(args[1]!)) {
    await cmdRead(Number(args[0]), Number(args[1]));
    return;
  }

  usage();
}

if (import.meta.main) {
  main().catch((e) => {
    console.error(e instanceof Error ? e.message : e);
    process.exit(1);
  });
}
