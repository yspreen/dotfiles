// no-agent-summary.js v3: Bun --preload hook that switches off Claude Code's `agent_summary`
// side-query. Unofficial, not affiliated with Anthropic. Tested on Linux, Claude Code 2.1.301.
// Install, env vars, verification and fail-open caveats: README.md.
//
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Flamerix AI (https://flamerix.ai). Provided "as is", without warranty;
// full license text: README.md.
// Contributions: Bedz01 (https://gist.github.com/Bedz01) — the --preload= form and the
// Claude-Code-only gate (gist comment 6448932).
//
// Anchors: the summarizer's debug-log line and its query-source id, both inside the timer
// callback on 2.1.301.
//
// Gate: installs only inside Claude Code itself, i.e. when Bun.main is the compiled CC entry AND
// process.execPath is a CC install, as measured on Linux: nix `.claude-wrapped`, npm
// `bin/claude.exe`, npm platform package `claude`, native installer `claude/versions/<semver>`.
// Any other bun or compiled Bun binary that inherits BUN_OPTIONS loads this file and does nothing;
// the one exception is a foreign binary built with `--outfile cli` and renamed to a CC-looking
// path (e.g. `claude`), where only timers whose callback carries an anchor change.
// Double load: bun loads one path once even if BUN_OPTIONS names it in both --preload forms;
// two different paths (an old and a new copy) both load, and the second v3 load is a no-op.
const INSTALLED = Symbol.for("flamerix.no-agent-summary.installed");
const CC_MAIN = "/$bunfs/root/cli";
const CC_EXEC_BASENAMES = [".claude-wrapped", "claude.exe", "claude"];
const CC_NATIVE_VERSION = /\/claude\/versions\/\d+\.\d+\.\d+$/;

function isClaudeCode() {
  if (typeof Bun === "undefined" || Bun.main !== CC_MAIN) return false;
  const p = process.execPath;
  const base = p.slice(p.lastIndexOf("/") + 1);
  return CC_EXEC_BASENAMES.includes(base) || CC_NATIVE_VERSION.test(p);
}

function install() {
  const fs = require("fs");
  const ANCHORS = ["[AgentSummary] Timer fired", "agent_summary"];
  const RAW_MODE = process.env.CC_AGENT_SUMMARY_MODE || "off";
  const MODE = RAW_MODE === "pass" ? "pass" : "off";
  if (RAW_MODE !== MODE) process.stderr.write(`[no-agent-summary] unknown mode ${RAW_MODE}, forcing off\n`);
  const LOG = process.env.CC_AGENT_SUMMARY_LOG;
  const log = (s) => { if (LOG) { try { fs.appendFileSync(LOG, `${new Date().toISOString()} pid=${process.pid} ${s}\n`); } catch {} } };

  const verdict = new WeakMap(); // fn -> bool (is the summary timer callback)
  function isSummaryTimer(fn) {
    if (typeof fn !== "function") return false;
    let v = verdict.get(fn);
    if (v === undefined) {
      try {
        const src = Function.prototype.toString.call(fn);
        v = ANCHORS.some((a) => src.includes(a));
      } catch { v = false; }
      verdict.set(fn, v);
    }
    return v;
  }

  let matched = 0;
  let suppressed = 0;
  const PROMISIFY = Symbol.for("nodejs.util.promisify.custom");
  const hookedFns = new WeakSet();
  function wrap(orig) {
    if (typeof orig !== "function") return orig;
    const hooked = function (fn, delay, ...args) {
      if (isSummaryTimer(fn)) {
        matched++;
        if (MODE === "off") {
          suppressed++;
          if (matched <= 20) log(`summary timer #${matched} suppressed (setTimeout, delay=${delay})`);
          const t = orig(() => {}, 2 ** 31 - 1); // clearTimeout-compatible handle, never fires
          if (t && typeof t.unref === "function") t.unref();
          return t;
        }
        if (matched <= 20) log(`summary timer #${matched} passed (control, setTimeout, delay=${delay})`);
      }
      return orig(fn, delay, ...args);
    };
    Object.defineProperty(hooked, "name", { value: "setTimeout" });
    // util.promisify(setTimeout) reads these; without the custom one it calls the wrapper
    // callback-last and node throws ERR_INVALID_ARG_TYPE.
    if (orig.__promisify__) hooked.__promisify__ = orig.__promisify__;
    if (orig[PROMISIFY]) hooked[PROMISIFY] = orig[PROMISIFY];
    hookedFns.add(hooked);
    return hooked;
  }

  globalThis.setTimeout = wrap(globalThis.setTimeout);
  const hookedApis = hookedFns.has(globalThis.setTimeout) ? "global.setTimeout" : "";

  const active = `preload active mode=${MODE} bun=${Bun.version} hooked=${hookedApis}`;
  log(active);
  if (LOG) process.on("exit", () => log(`exit: ${suppressed} summary timer(s) suppressed, ${matched} matched`));
  const MARKER = process.env.CC_AGENT_SUMMARY_MARKER;
  if (MARKER) {
    try { fs.writeFileSync(MARKER, `${active} pid=${process.pid}\n`); }
    catch (e) { process.stderr.write(`[no-agent-summary] cannot write marker ${MARKER}: ${e.message}\n`); }
  }
}

if (isClaudeCode() && !globalThis[INSTALLED]) {
  globalThis[INSTALLED] = true;
  install();
}
