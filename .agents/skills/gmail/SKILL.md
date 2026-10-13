---
name: gmail
description: Work with the user's gmail inbox, read and write
---

You can run actions to interface with gmail like this command:
`codex --yolo --model=$model -c model_reasoning_effort="low" e "/gmail Please read the user's latest email" 2>/dev/null`

where `$model` can be one of:
gpt-5.6-terra
gpt-5.6-sol

and `Please read the user's latest email` is an example action.

You should default to terra. Sol is only intended for tricky tasks. But reading and writing emails isn't tricky. So Terra should be the default.

You can tell codex to run any of these actions with the `/gmail` prefix:

Gmail tools available now: 23 actions.

## Account

- `gmail_get_profile`
  - Get authenticated Gmail account profile.
  - Returns email address and profile metadata.

- `gmail_list_labels`
  - List system and custom Gmail labels.
  - Returns label names, IDs, message counts, unread counts.
  - Useful for inbox/unread totals.
  - Can filter by label names.

- `gmail_create_label`
  - Create a custom Gmail label.
  - Set:
    - Label name
    - Label-list visibility
    - Message-list visibility
  - Existing label is returned instead of duplicated.

## Search

- `gmail_search_emails`
  - Search Gmail messages.
  - Supports Gmail search syntax:
    - `from:alice@example.com`
    - `to:me`
    - `subject:invoice`
    - `has:attachment`
    - `after:2026/01/01`
    - `before:2026/02/01`
    - `newer_than:7d`
    - `older_than:30d`
    - `label:Receipts`
    - `category:promotions`
    - `is:unread`
    - `is:starred`
    - `-in:spam`
    - `-in:trash`
    - `-category:promotions`
  - Returns matching email metadata and content summaries.
  - Supports pagination and maximum result count.

- `gmail_search_email_ids`
  - Same search capability.
  - Returns message IDs.
  - Better for follow-up actions such as archive, trash, label, read, or forward.

Examples:

```text
after:2026/01/01 before:2026/02/01
```

```text
from:billing@example.com has:attachment newer_than:30d
```

```text
subject:invoice is:unread -in:trash
```

```text
label:Receipts after:2025/01/01
```

Search by exact date works with `after:` and `before:`. Gmail date boundaries can be timezone-sensitive, so use the day before or after when an exact inclusive range matters.

## Reading email

- `gmail_read_email`
  - Read one message.
  - Returns:
    - Sender
    - Recipients
    - Subject
    - Date
    - Body
    - Snippet
    - Labels
    - Attachments
    - Inline images
  - Can include raw MIME and base64url payload for exact HTML/MIME inspection.

- `gmail_batch_read_email`
  - Read multiple messages in one operation.
  - Returns full message bodies and metadata.

- `gmail_read_email_thread`
  - Read an entire conversation.
  - Accepts either:
    - A message ID
    - A thread ID
  - Defaults to the 20 most recent messages.
  - Supports a custom message limit.

- `gmail_batch_read_email_threads`
  - Read multiple conversation threads.
  - Input must contain either all message IDs or all thread IDs.
  - Supports a maximum number of messages per thread.

## Attachments

- `gmail_read_attachment`
  - Read one attachment from a Gmail message.
  - Workflow:
    1. Search or read the parent email.
    2. Inspect its attachment metadata.
    3. Use the returned attachment ID or exact filename.
    4. Read the attachment.
  - Only supported MIME types can be read.
  - Supports regular attachments and inline images.

Can it download attachments?

- It can retrieve/read supported attachments.
- It does not expose a separate “save attachment to my computer” Gmail action.
- If the attachment result provides usable file data, I can work with that data in the current task.
- Unsupported MIME types cannot be read through this action.
- I cannot invent attachment IDs. I must use IDs returned by Gmail.

## Drafts

- `gmail_list_drafts`
  - List saved Gmail drafts.
  - Returns draft IDs and summary metadata.
  - Supports pagination and result limits.

- `gmail_create_draft`
  - Create a draft without sending.
  - Supports:
    - To
    - CC
    - BCC
    - Subject
    - Markdown body
    - Plain-text body
    - HTML body
    - Body from a local file
    - File attachments
    - Reply threading
  - Returns a Gmail draft ID.

- `gmail_update_draft`
  - Edit an existing draft in place.
  - Can update:
    - To
    - CC
    - BCC
    - Subject
    - Body
    - HTML body
    - Body file
    - Content type
  - Omitted fields remain unchanged.
  - Empty strings clear fields when explicitly requested.
  - Drafts containing attachments cannot be edited through this action.

- `gmail_send_draft`
  - Send an existing saved draft.
  - Requires the exact draft ID.
  - Sending is an external side effect, so I use it only after explicit instruction or clear confirmation.

## Sending and replying

- `gmail_send_email`
  - Send a new email immediately.
  - Supports:
    - To
    - CC
    - BCC
    - Subject
    - Markdown
    - Plain text
    - HTML
    - Body files
    - File attachments
    - Reply threading
  - Requires explicit recipient and message content.

- `gmail_forward_emails`
  - Forward one or more existing messages.
  - Supports:
    - To
    - CC
    - BCC
    - Optional Markdown note
  - Preserves original message attachments.
  - Each selected source message becomes a separate forwarded email.

## Message organization

- `gmail_apply_labels_to_emails`
  - Add or remove labels from selected messages.
  - Uses label names.
  - Can create missing labels automatically.
  - Works on individual Gmail messages.

- `gmail_batch_modify_email`
  - Add or remove labels from multiple messages.
  - Uses Gmail label IDs, not display names.
  - `apply_labels_to_emails` is usually easier.

- `gmail_bulk_label_matching_emails`
  - Apply a label to every message matching a Gmail query.
  - Can create the label if missing.
  - Can archive matching messages after labeling.
  - Useful for large batches.

Example:

```text
query: from:vendor@example.com older_than:90d
label_name: Archived Vendors
archive: true
```

- `gmail_archive_emails`
  - Remove selected messages from Inbox.
  - Messages remain in Gmail.
  - Can be found through search later.

- `gmail_delete_emails`
  - Move selected messages to Trash.
  - This is Gmail-style deletion, not immediate permanent deletion.
  - Gmail’s normal Trash retention rules apply.

## Supported identifiers

Actions require exact Gmail IDs returned by Gmail tools:

- Message IDs for individual email actions
- Thread IDs for thread actions
- Draft IDs for draft updates and sending
- Label IDs for low-level batch label changes
- Label names for higher-level label actions

I cannot use these as substitutes:

- Subject lines
- Email addresses
- Gmail URLs
- Thread IDs where message IDs are required
- Draft message IDs where draft IDs are required
- Guessed or truncated attachment IDs

## Actions with external effects

These change Gmail data or send mail:

- Send email
- Send draft
- Create draft
- Update draft
- Forward email
- Archive email
- Move email to Trash
- Add/remove labels
- Create labels
- Bulk-label messages

Search, profile lookup, label listing, reading messages, reading threads, and reading attachments are read-only.

## Plugin status

The Gmail connector is callable in this session. The available Gmail surface covers:

- Search
- Date filtering
- Reading messages
- Reading threads
- Reading supported attachments
- Draft creation
- Draft listing
- Draft updates
- Draft sending
- New email sending
- Forwarding
- Labels
- Archiving
- Trash
