---
name: agent-card
description: Manage virtual Visa cards for AI agents with AgentCard. Use when the user gives you permission to use agent cards
---

# AgentCard

The AgentCard MCP server is not in the MCP registry. Call it through the MCP inspector CLI. Write the full command each time (zsh does not word-split a `$VAR` holding it).

```bash
bunx @modelcontextprotocol/inspector --cli bun ~/dotfiles/scripts/agentcard.ts --method tools/call --tool-name <tool> --tool-arg key=value --tool-arg other=value
```

If a call fails on an unknown tool or argument, check the live schema with `--method tools/list`.

## Tools

| Tool | Args | Does |
|------|------|------|
| `create_agent_handle` | `name` | Create a handle. Cards belong to a handle. |
| `list_cards` | `handle` | List the handle's cards by index (`card`: 1, 2, ...) with limits and expirations. No card numbers. |
| `get_card_details` | `handle`, `card` | Full details for one card: number, expiry, CVC, name, billing address. |
| `create_card` | `handle`, optional `monthly_limit_usd`, `max_uses`, `expires_at` | Create a card. Returns its index, not its number. `max_uses`: expires after n uses. `expires_at`: UTC ISO 8601, e.g. `2026-12-31T23:59:59Z`. |

Example:

```bash
bunx @modelcontextprotocol/inspector --cli bun ~/dotfiles/scripts/agentcard.ts --method tools/call --tool-name create_card --tool-arg handle=shopper --tool-arg monthly_limit_usd=25 --tool-arg max_uses=1
```

Fetch details only at checkout:

```bash
bunx @modelcontextprotocol/inspector --cli bun ~/dotfiles/scripts/agentcard.ts --method tools/call --tool-name get_card_details --tool-arg handle=shopper --tool-arg card=1
```

Nothing else exists: no closing, pausing, funding, balances or transactions. If the user asks for those, say the server does not support it.

## Safety rules

- Confirm with the user before creating a card. Cards spend real money.
- Prefer tight limits: set a monthly limit plus a use count or expiry date unless the user says otherwise.
- Call `get_card_details` only when you need the card to pay. Never display the card number (PAN) or CVC unless the user explicitly asks.
- Format money as dollars (`$50.00`).
- Track handles and card indexes across the conversation so the user doesn't repeat them.
