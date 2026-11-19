#!/usr/bin/env bun
// Codex plan limits, read the way T3 Code does (pingdotgg/t3code apps/server/src/provider/codexUsageLimits.ts):
// ask `codex app-server` (JSON-RPC over stdio) for `account/rateLimits/read`. No model turn, no usage spent.
const die = (why: string): never => (console.error(`codex-usage: ${why}`), process.exit(1));
const proc = Bun.spawn(["codex", "app-server"], { stdin: "pipe", stdout: "pipe", stderr: "ignore" });
const send = (m: object) => proc.stdin.write(JSON.stringify(m) + "\n");
setTimeout(() => (proc.kill(), die("codex app-server did not answer in 20 s")), 20_000).unref();
send({ id: 1, method: "initialize", params: { clientInfo: { name: "codex-usage", title: null, version: "1" }, capabilities: null } });
send({ method: "initialized" });
send({ id: 2, method: "account/rateLimits/read" });
let buf = "", res: any;
for await (const chunk of proc.stdout) {
  buf += new TextDecoder().decode(chunk);
  const line = buf.split("\n").map((l) => (l.startsWith("{") ? JSON.parse(l) : {})).find((m) => m.id === 2);
  if (line) { res = line; break; }
}
proc.kill();
if (!res) die("codex app-server exited without an answer");
if (res.error) die(`rateLimits/read failed: ${res.error.message} (not logged in or endpoint changed?)`);
const snap = res.result.rateLimitsByLimitId?.codex ?? res.result.rateLimits;
const win = (w: any) => w && typeof w.usedPercent === "number"
  ? { usedPercent: w.usedPercent, resetsAt: w.resetsAt ? new Date(w.resetsAt * 1000).toISOString() : null } : die("no window in response");
const out = { fiveHour: win(snap?.primary), weekly: win(snap?.secondary) };
if (process.argv.includes("--json")) console.log(JSON.stringify(out));
else for (const [name, w, fmt] of [["5h", out.fiveHour, { hour: "2-digit", minute: "2-digit" }], ["weekly", out.weekly, { weekday: "short", hour: "2-digit", minute: "2-digit" }]] as const)
  console.log(`${name} ${w.usedPercent}% used, resets ${w.resetsAt ? new Date(w.resetsAt).toLocaleString("en-GB", fmt) : "?"}`);
