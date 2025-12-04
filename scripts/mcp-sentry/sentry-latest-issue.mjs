#!/usr/bin/env node
import { EventEmitter } from "events";
import {
  Client,
  NodeOAuthClientProvider,
  connectToRemoteServer,
  createLazyAuthCoordinator,
  parseCommandLineArgs,
  version as mcpRemoteVersion,
} from "mcp-remote/dist/chunk-RGTAVJIZ.js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const SERVER_URL = "https://mcp.sentry.dev/mcp";
const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const CONFIG_PATH = path.join(SCRIPT_DIR, ".project-cache.json");

// Suppress noisy connection logs from mcp-remote while keeping real errors.
{
  const originalError = console.error;
  console.error = (...args) => {
    const first = args[0];
    if (
      typeof first === "string" &&
      (first.includes("Using existing client port") ||
        first.includes("Connecting to remote server") ||
        first.includes("Using transport strategy") ||
        first.includes(
          "Connected to remote server using StreamableHTTPClientTransport"
        ))
    ) {
      return;
    }
    originalError(...args);
  };
}

async function connectToSentry() {
  const parsed = await parseCommandLineArgs(
    [SERVER_URL],
    "Usage: sentry-latest-issue"
  );
  const events = new EventEmitter();
  const authCoordinator = createLazyAuthCoordinator(
    parsed.serverUrlHash,
    parsed.callbackPort,
    events,
    parsed.authTimeoutMs
  );
  const authProvider = new NodeOAuthClientProvider({
    serverUrl: parsed.serverUrl,
    callbackPort: parsed.callbackPort,
    host: parsed.host,
    clientName: "sentry-latest-issue-script",
    staticOAuthClientMetadata: parsed.staticOAuthClientMetadata,
    staticOAuthClientInfo: parsed.staticOAuthClientInfo,
    serverUrlHash: parsed.serverUrlHash,
  });
  const client = new Client(
    { name: "sentry-latest-issue-script", version: mcpRemoteVersion },
    { capabilities: {} }
  );
  let authServer = null;
  const authInitializer = async () => {
    const authState = await authCoordinator.initializeAuth();
    authServer = authState.server ?? null;
    if (authState.skipBrowserAuth) {
      // Give the other instance a moment to finish writing tokens to disk.
      await new Promise((res) => setTimeout(res, 1000));
    }
    return {
      waitForAuthCode: authState.waitForAuthCode,
      skipBrowserAuth: authState.skipBrowserAuth,
    };
  };
  await connectToRemoteServer(
    client,
    parsed.serverUrl,
    authProvider,
    parsed.headers,
    authInitializer,
    parsed.transportStrategy
  );
  return {
    client,
    async close() {
      await client.close();
      if (authServer) {
        authServer.close();
      }
    },
  };
}

async function callToolText(client, name, args) {
  const response = await client.callTool({ name, arguments: args });
  const texts =
    response.content
      ?.filter((item) => item.type === "text")
      .map((item) => item.text.trim()) ?? [];
  return texts.join("\n\n").trim();
}

async function fetchOrganizations(client) {
  const text = await callToolText(client, "find_organizations", {});
  return parseOrganizations(text);
}

function parseOrganizations(text) {
  const normalized = text.replace(/\r/g, "");
  const blocks = [];
  const regex = /## \*\*(.+?)\*\*([\s\S]*?)(?=## \*\*|$)/g;
  let match;
  while ((match = regex.exec(normalized))) {
    const slug = match[1].trim();
    const block = match[2];
    const webUrlMatch = block.match(/\*\*Web URL:\*\*\s*(\S+)/);
    const regionMatch = block.match(/\*\*Region URL:\*\*\s*(\S+)/);
    blocks.push({
      slug,
      webUrl: webUrlMatch?.[1] ?? null,
      regionUrl: regionMatch?.[1] ?? null,
    });
  }
  return blocks;
}

async function fetchProjects(client, organizationSlug) {
  const text = await callToolText(client, "find_projects", {
    organizationSlug,
  });
  return parseProjects(text);
}

function parseProjects(text) {
  const matches = [...text.matchAll(/- \*\*(.+?)\*\*/g)];
  return matches.map((match) => match[1].trim());
}

function parseSearchIssues(text) {
  if (!text || /No issues found/i.test(text)) {
    return null;
  }
  const issueBlock = text.match(
    /##\s*1\.\s*\[(.+?)\]\((.+?)\)([\s\S]*?)(?=\n##\s*\d+\.|\n##\s*Next Steps|$)/
  );
  if (!issueBlock) {
    return null;
  }
  const [, issueId, issueUrl, block] = issueBlock;
  const summaryMatch = block.match(/\*\*(.+?)\*\*/);
  const bulletMatches = [...block.matchAll(/- \*\*(.+?)\*\*:\s*(.+)/g)];
  const bulletMap = new Map(
    bulletMatches.map(([_, key, value]) => [key.toLowerCase(), value.trim()])
  );
  return {
    issueId: issueId.trim(),
    issueUrl: issueUrl.trim(),
    description: summaryMatch?.[1]?.trim() ?? "",
    status: bulletMap.get("status") ?? null,
    users: bulletMap.get("users") ?? null,
    events: bulletMap.get("events") ?? null,
    firstSeenSummary: bulletMap.get("first seen") ?? null,
    lastSeenSummary: bulletMap.get("last seen") ?? null,
    culprit: bulletMap.get("culprit") ?? null,
  };
}

function extractField(text, label) {
  const regex = new RegExp(`\\*\\*${label}\\*\\*:\\s*(.+)`);
  const match = text.match(regex);
  return match ? match[1].trim() : undefined;
}

function extractSection(text, startMarker, endMarker) {
  const startIndex = text.indexOf(startMarker);
  if (startIndex === -1) {
    return "";
  }
  const start = startIndex + startMarker.length;
  const tail = text.slice(start);
  if (!endMarker) {
    return tail.trim();
  }
  const endIndex = tail.indexOf(endMarker);
  if (endIndex === -1) {
    return tail.trim();
  }
  return tail.slice(0, endIndex).trim();
}

function parseTagLines(section) {
  const tags = [];
  const regex = /\*\*(.+?)\*\*:\s*(.+)/g;
  let match;
  while ((match = regex.exec(section))) {
    tags.push({ key: match[1].trim(), value: match[2].trim() });
  }
  return tags;
}

function parseAdditionalContext(section) {
  const contexts = [];
  const lines = section
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);
  let current = null;
  for (const line of lines) {
    const heading = line.match(/^\*\*(.+?)\*\*$/);
    if (heading) {
      current = { section: heading[1].trim(), entries: [] };
      contexts.push(current);
      continue;
    }
    const kv = line.match(/^([^:]+):\s*(.+)$/);
    if (kv && current) {
      current.entries.push({ key: kv[1].trim(), value: kv[2].trim() });
    }
  }
  return contexts;
}

function parseIssueDetails(text) {
  const normalized = text.replace(/\r/g, "");
  const description = extractField(normalized, "Description");
  const culprit = extractField(normalized, "Culprit");
  const firstSeen = extractField(normalized, "First Seen");
  const lastSeen = extractField(normalized, "Last Seen");
  const occurrences = extractField(normalized, "Occurrences");
  const usersImpacted = extractField(normalized, "Users Impacted");
  const status = extractField(normalized, "Status");
  const platform = extractField(normalized, "Platform");
  const project = extractField(normalized, "Project");
  const issueUrl = extractField(normalized, "URL");
  const eventId = extractField(normalized, "Event ID");
  const occurredAt = extractField(normalized, "Occurred At");
  const message = extractSection(normalized, "**Message**:", "\n###");
  const tagsSection = extractSection(
    normalized,
    "### Tags",
    "### Additional Context"
  );
  const additionalSection = extractSection(
    normalized,
    "### Additional Context",
    "# Using this information"
  );
  return {
    description,
    culprit,
    firstSeen,
    lastSeen,
    occurrences,
    usersImpacted,
    status,
    platform,
    project,
    issueUrl,
    eventId,
    occurredAt,
    message,
    tags: parseTagLines(tagsSection),
    additionalContext: parseAdditionalContext(additionalSection),
    rawText: normalized,
  };
}

function formatDate(value) {
  if (!value) return "unknown";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }
  return `${date.toISOString()} (${date.toLocaleString()})`;
}

function parseArgs(argv) {
  const options = {
    orgSlug: undefined,
    query: "is:unresolved !status:archived sort:date",
    raw: true,
    json: false,
    setProject: undefined,
    setOrg: undefined,
    cwd: undefined,
  };
  for (const arg of argv) {
    if (arg.startsWith("--org=")) {
      options.orgSlug = arg.split("=")[1];
    } else if (arg.startsWith("--query=")) {
      options.query = arg.split("=")[1];
    } else if (arg === "--no-raw") {
      options.raw = false;
    } else if (arg === "--json") {
      options.json = true;
    } else if (arg.startsWith("--set-project=")) {
      options.setProject = arg.split("=")[1];
    } else if (arg.startsWith("--set-org=")) {
      options.setOrg = arg.split("=")[1];
    } else if (arg.startsWith("--cwd=")) {
      options.cwd = arg.split("=")[1];
    }
  }
  return options;
}

function loadConfig() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  } catch {
    return {};
  }
}

function saveConfig(config) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
}

function findConfigForPath(cwd, config) {
  let current = path.resolve(cwd);
  while (true) {
    if (config[current]) {
      return { path: current, value: config[current] };
    }
    const parent = path.dirname(current);
    if (parent === current) break; // reached filesystem root
    current = parent;
  }
  return null;
}

function isOpenStatus(statusText) {
  if (!statusText) return true; // be permissive if unknown
  const normalized = statusText.toLowerCase();
  // Check for explicitly open statuses
  if (
    normalized === "unresolved" ||
    normalized === "regressed" ||
    normalized.includes("unhandled")
  ) {
    return true;
  }
  // Check for closed statuses
  return !(
    normalized === "resolved" ||
    normalized.includes("closed") ||
    normalized.includes("archived") ||
    normalized.includes("ignored")
  );
}

async function fetchLatestIssueForProject(client, org, projectSlug, query) {
  try {
    const searchText = await callToolText(client, "search_issues", {
      organizationSlug: org.slug,
      projectSlugOrId: projectSlug,
      naturalLanguageQuery: query,
      limit: 1,
    });
    const summary = parseSearchIssues(searchText);
    if (!summary) {
      return null;
    }
    if (!isOpenStatus(summary.status)) {
      return null;
    }
    const detailsText = await callToolText(client, "get_issue_details", {
      organizationSlug: org.slug,
      issueId: summary.issueId,
      regionUrl: org.regionUrl ?? undefined,
    });
    const details = parseIssueDetails(detailsText);
    const lastSeenMs = details.lastSeen
      ? Date.parse(details.lastSeen)
      : undefined;
    return {
      projectSlug,
      org,
      summary,
      details,
      lastSeenMs,
      status: details.status ?? summary.status,
    };
  } catch (error) {
    console.error(
      `Failed to fetch latest issue for project ${projectSlug}:`,
      error.message ?? error
    );
    return null;
  }
}

function printIssue(latest, options) {
  console.log("=== Latest Issue ===");
  console.log(`Organization: ${latest.org.slug}`);
  if (latest.org.regionUrl) {
    console.log(`Region URL: ${latest.org.regionUrl}`);
  }
  console.log(`Project: ${latest.projectSlug}`);
  console.log(`Issue ID: ${latest.summary.issueId}`);
  if (latest.details.description) {
    console.log(`Title: ${latest.details.description}`);
  } else if (latest.summary.description) {
    console.log(`Title: ${latest.summary.description}`);
  }
  console.log(
    `Status: ${latest.details.status ?? latest.summary.status ?? "unknown"}`
  );
  console.log(
    `Users impacted: ${
      latest.details.usersImpacted ?? latest.summary.users ?? "unknown"
    }`
  );
  console.log(
    `Occurrences / events: ${
      latest.details.occurrences ?? latest.summary.events ?? "unknown"
    }`
  );
  console.log(
    `First seen: ${formatDate(latest.details.firstSeen)}${
      latest.summary.firstSeenSummary
        ? ` (${latest.summary.firstSeenSummary})`
        : ""
    }`
  );
  console.log(
    `Last seen: ${formatDate(latest.details.lastSeen)}${
      latest.summary.lastSeenSummary
        ? ` (${latest.summary.lastSeenSummary})`
        : ""
    }`
  );
  if (latest.details.culprit || latest.summary.culprit) {
    console.log(`Culprit: ${latest.details.culprit ?? latest.summary.culprit}`);
  }
  console.log(`URL: ${latest.details.issueUrl ?? latest.summary.issueUrl}`);
  console.log("");
  console.log("--- Recent Event ---");
  console.log(`Event ID: ${latest.details.eventId ?? "unknown"}`);
  console.log(`Occurred at: ${formatDate(latest.details.occurredAt)}`);
  if (latest.details.message) {
    console.log("Message:");
    console.log(latest.details.message);
  }
  console.log("");
  if (latest.details.tags.length) {
    console.log("Tags:");
    for (const tag of latest.details.tags) {
      console.log(`- ${tag.key}: ${tag.value}`);
    }
    console.log("");
  }
  if (latest.details.additionalContext.length) {
    console.log("Additional Context:");
    for (const section of latest.details.additionalContext) {
      console.log(`* ${section.section}`);
      for (const entry of section.entries) {
        console.log(`    - ${entry.key}: ${entry.value}`);
      }
    }
    console.log("");
  }
  if (options.raw) {
    console.log("--- Raw Sentry Detail ---");
    console.log(latest.details.rawText);
  }
  if (options.json) {
    console.log("\n--- JSON Payload ---");
    console.log(JSON.stringify(latest, null, 2));
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const { client, close } = await connectToSentry();
  try {
    const orgs = await fetchOrganizations(client);
    if (!orgs.length) {
      throw new Error("No Sentry organizations found for this account.");
    }
    const preferredOrg = options.orgSlug
      ? orgs.find((entry) => entry.slug === options.orgSlug)
      : orgs[0];
    if (!preferredOrg) {
      throw new Error(
        `Organization '${options.orgSlug}' was not returned by the MCP server.`
      );
    }

    const config = loadConfig();
    let cwd = process.cwd();
    if (options.cwd) {
      cwd = options.cwd;
    }
    const resolvedCwd = path.resolve(cwd);

    // Setting mode: persist mapping for this cwd
    if (options.setProject) {
      const targetOrg = options.setOrg
        ? orgs.find((o) => o.slug === options.setOrg)
        : preferredOrg;
      if (!targetOrg) {
        throw new Error(`Organization '${options.setOrg}' not found.`);
      }
      const projectsForOrg = await fetchProjects(client, targetOrg.slug);
      if (!projectsForOrg.includes(options.setProject)) {
        throw new Error(
          `Project '${options.setProject}' not found in organization '${targetOrg.slug}'.`
        );
      }
      config[resolvedCwd] = {
        orgSlug: targetOrg.slug,
        projectSlug: options.setProject,
      };
      saveConfig(config);
      console.log(
        `Configured project '${options.setProject}' for working directory '${resolvedCwd}'.`
      );
      return;
    }

    const cachedEntry = findConfigForPath(resolvedCwd, config);
    const cached = cachedEntry?.value;
    if (!cached) {
      const projectsForOrg = await fetchProjects(client, preferredOrg.slug);
      console.log("No project is configured for this working directory.");
      console.log("To configure for this path, rerun with:\n");
      console.log("sentry-latest --set-project=<project>\n");
      console.log("Where project is one of:");
      for (const p of projectsForOrg) {
        console.log(` ${p}`);
      }
      return;
    }

    const activeOrg =
      orgs.find((o) => o.slug === cached.orgSlug) ?? preferredOrg;
    const projects = await fetchProjects(client, activeOrg.slug);
    if (!projects.includes(cached.projectSlug)) {
      throw new Error(
        `Cached project '${cached.projectSlug}' not found in org '${activeOrg.slug}'. Reconfigure with --set-project.`
      );
    }

    const latest = await fetchLatestIssueForProject(
      client,
      activeOrg,
      cached.projectSlug,
      options.query
    );

    if (!latest) {
      console.log("No issues found for the selected scope.");
      return;
    }

    printIssue(latest, options);
  } finally {
    await close();
  }
}

main().catch((error) => {
  console.error(
    "Failed to fetch latest Sentry issue:",
    error?.message ?? error
  );
  process.exit(1);
});
