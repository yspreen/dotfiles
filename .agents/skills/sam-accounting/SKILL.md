---
name: sam-accounting
description: Settle Remy costs with Sam Beckman. Use when asked to tally Remy server/AI costs, figure out what Sam owes Nick, or draft the cost reimbursement message to Sam on WhatsApp.
---

# Sam accounting (Remy)

Nick and Sam Beckman co-own the Remy Reminders app. Sam receives Apple/Google payouts (AUD) and sends Nick his share by Wise around the 4th Monday of each month. Nick pays the infra costs (USD) and only has to report them. Sam does the AUD conversion.

## The math

Agreed formula (WhatsApp, 2026-05-28): Nick gets `(payouts - costs) / 2 + costs`.

Sam's monthly transfers are a plain 50% of payouts (`P/2`) with no costs taken out. So the amount still owed for any unsettled costs `C` is:

```
(P - C)/2 + C - P/2 = C/2
```

Sam owes **half of the costs Nick paid since the last settlement**. Payout amounts don't matter for the top-up.

## Getting the data

Count only costs actually charged to Nick's card after the "last settled" date below. Use payment dates, not usage periods.

1. **xAI (Grok)**: Gmail `from:(receipts@stripe.com OR noreply@x.ai) (grok OR xai)`. Each "Your Grok xAI receipt" is a $5 prepaid top-up. Also see console.x.ai, team hockey-labs, Billing. All xAI keys count as Remy.
2. **Convex**: dashboard.convex.dev/t/yannick-spreen/settings/billing, Invoices table. Gmail `from:billing@convex.dev` only has emails for invoices that hit the card. Open each invoice: if it shows "Applied balance", the card was not charged (e.g. NCNFWC-00008, Sep 2026, $5.17 covered by balance). Count the whole Convex invoice as Remy (agreed simplification, even though the team also hosts pacey, tanztech-tokyo, tanstack-echo-chat, daily-question-for-couples).
3. **Google Vertex (Gemini)**: Google Cloud billing account "Remy" `0134D2-3BAB42-1A94E8`, project `remy-486120`. Reports grouped by month, plus Transactions for what was charged. All Gemini usage there counts as Remy.
4. **Last settlement + Sam's payments**: WhatsApp chat "Sam Beckman" (`personal:238598334976227@lid`). History is huge: page with `next_cursor`, parse saved JSON with jq, or hand paging to a subagent.

## Message to Sam

Lowercase, casual, in Nick's voice, no em dashes. List each provider with dates and amounts, the USD total, the formula, and the amount owed (half). Ask him to convert to AUD and add it to the next transfer. Offer invoices. Never send without Nick confirming the exact text.

## Self-update rule

**Whenever the cost message to Sam is sent in WhatsApp, edit this SKILL.md before finishing:** move the sent tally into "Last time we got settled up" (replace the old entry, keep a one-line history entry), set the new cutoff date, and clear "Pending". If Sam later confirms payment, add that to the entry.

## Last time we got settled up

- **Date:** 2026-05-29
- **Covered:** all Nick's costs up to 2026-05-28. About $60 USD (domain, servers, AI), which Sam converted to $51.72 AUD.
- **Paid:** Sam sent $549.02 AUD on 2026-05-29. That was the full settlement of March and April payouts plus costs.
- **Cutoff for the next tally:** count costs charged **after 2026-05-28**.

### History
- 2026-05-29: costs to 2026-05-28 settled, $549.02 AUD total payout.

## Pending (drafted, not sent yet)

Drafted 2026-11-02, covering 2026-05-29 to 2026-11-02:

| Provider | Charges | USD |
|---|---|---|
| xAI | $5 on Jun 30, Jul 7, Aug 5, Aug 23, Oct 11 | 25.00 |
| Convex | Sep 13 #7 $5.17, Oct 13 #9 $1.92 (Jun–Aug $0, #8 paid by balance) | 7.09 |
| Google Vertex | May–Oct usage (Oct $0.03 initially declined) | 0.67 |
| **Total** | | **32.76** |

Owed by Sam: **$16.38 USD**. Open question: where the $5.17 Convex balance that paid #8 came from. If Nick prepaid it, add $5.17 to costs.

Not yet included (charged after 2026-11-02 or not yet charged): Convex Nov 13 invoice (~$1.21).
