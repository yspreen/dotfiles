---
name: png-to-svg
description: Convert a user-supplied PNG to SVG through VectorArt.ai using a fresh Chrome Incognito session and a new disposable agent-email account, then download the SVG, sign out, and close the tab.
---

# PNG to SVG through VectorArt.ai

Use this skill when the user asks to convert a PNG through:

`https://vectorart.ai/edit/png-to-svg`

The required flow is:

1. Open a new Chrome Incognito window.
2. Create a new agent-email inbox.
3. Create and confirm a new VectorArt.ai account.
4. Upload the requested PNG.
5. Convert with the site's default mode.
6. Download the SVG into the requested folder.
7. Sign out.
8. Close the Incognito tab or window.

## Required skills

Before acting, read these skills completely:

- `agent-email`
- `chrome:control-chrome`
- `computer-use:computer-use` when Chrome UI control is needed to create the Incognito window or change extension settings

Use Chrome browser controls for webpage interaction. Use Computer Use only for browser chrome that the page-control API cannot operate, such as opening an Incognito window or enabling extension access there.

## Determine the input and output

- If the user attached or named a PNG, use its exact absolute path.
- If the user says "latest PNG," resolve the newest PNG in the requested folder by modification time.
- Record the source basename. Prefer output name `<source-basename>.svg`.
- Never upload a different image merely because it is newer.

## Prepare Chrome Incognito

Chrome's ChatGPT extension must have both settings enabled:

- **Allow in Incognito**
- **Allow access to file URLs**

Check `chrome://extensions/?id=hehggadaopoacecdllhhajmbjkdcmajg` through Computer Use when needed. Enable missing settings only when the user has authorized the change. These are persistent extension-permission changes, so follow Computer Use confirmation policy.

Open a new Incognito window with Chrome's **New Incognito Window** command or `Command+Shift+N`. Verify the window title contains `Incognito` and the page says `You've gone Incognito`.

The Chrome extension may expose the Incognito tab through the same browser instance as regular tabs. Use `browser.user.openTabs()`, select the exact current object whose title is `New Incognito Tab` and URL is `chrome://newtab/`, then claim that exact object. Never guess a tab ID.

Name the Chrome automation session before claiming the tab. Example:

```js
await chrome.nameSession("🕶️ Incognito PNG to SVG");
```

## Create a new inbox

Create one fresh inbox per conversion:

```bash
bun ~/dotfiles/scripts/mailtm.ts
```

Save both returned values:

- inbox number
- email address

Use a new strong random password for the VectorArt.ai account. Keep it only for this workflow. Do not expose the password in the final response.

## Create and confirm the account

In the claimed Incognito tab:

1. Open `https://vectorart.ai/login`.
2. Confirm the page is in **Sign up** mode.
3. Enter the new agent-email address and generated password.
4. Submit **Sign up**.
5. Verify the page says to check email for a confirmation link.

Read the newest inbox message:

```bash
bun ~/dotfiles/scripts/mailtm.ts <inbox-number>
```

If no message has arrived, retry after a short delay. If repeated checks still show an empty inbox, submit **Sign up** once more with the same email and password to trigger another confirmation message, then poll the same inbox again. Do not create another inbox or account unless the signup clearly failed.

Open the exact confirmation URL from the email in the same Incognito tab. Confirmation links are one-time links. After the redirect reaches VectorArt.ai, wait for the URL fragment to be consumed, then allow several more seconds for the client-side session to settle before navigating away. The top navigation can briefly show `Sign in` during this process.

Verify sign-in using the top navigation, not footer links. Footer always contains `Sign in` and `Sign up`, even while authenticated. An authenticated page shows the account/avatar button in the top navigation.

Verify the settled session by opening `https://vectorart.ai/login`. An authenticated account is redirected to `/browse` and shows the blank account/avatar button in the top navigation. This redirect is a stronger signal than the briefly stale home-page header.

If confirmation succeeds but the session still does not persist after that check, sign in explicitly with the new email and password. Do not reuse the one-time confirmation URL after it has been consumed.

## Upload the PNG

Before uploading, read the browser's `file-uploads` documentation.

Open:

`https://vectorart.ai/edit/png-to-svg`

Use the visible upload target rather than clicking a hidden input directly when the hidden input does not emit a chooser:

```js
const chooserPromise = tab.playwright.waitForEvent("filechooser", { timeoutMs: 10000 });
await tab.playwright.getByText("Drop your PNG here or click to select", { exact: true }).click();
const chooser = await chooserPromise;
await chooser.setFiles([absolutePngPath], { timeoutMs: 30000 });
```

Verify the page shows `Uploaded image` and the prompt placeholder changes to `Vectorize this image`.

If upload fails in Chrome, follow the `chrome-file-upload-troubleshooting` documentation. Do not switch to a non-Incognito session.

## Convert with default mode

- Leave all conversion settings unchanged.
- Confirm the visible default style remains **Simple**.
- Do not open options.
- Click the exact **Create** button associated with the uploaded image.
- Wait for conversion to finish, checking fresh page state at reasonable intervals.

Large or complex PNGs can remain on `Loading...` for two to three minutes. Poll in 10-15 second increments and keep the same page untouched while loading. When browser control runs through a tool with its own execution timeout, keep each page wait comfortably below that timeout or explicitly set the tool timeout at least 10 seconds higher. A page wait equal to the default 30-second tool timeout can reset the control session even though the site continues processing.

The page can show `0 Credits left` while a newly created account's first conversion is completing. Do not treat that text alone as failure. Keep waiting until either `Download SVG` appears or an actual subscription dialog appears.

If Chrome restarts or the Incognito window closes during conversion, reopen Incognito and sign into the fresh account created for the current task. Check `/my/creations` and `/my/downloads` before uploading again. If neither contains the result and another **Create** attempt presents a subscription dialog, the interrupted attempt consumed the account's one-time credit. Sign out, close that Incognito session, create a new inbox/account, and retry. Never purchase a subscription to recover an interrupted free conversion.

If the site presents a subscription or payment wall, do not purchase a plan unless the user separately authorized the exact recurring charge. Record that conversion was blocked, then continue cleanup: sign out and close the Incognito tab.

## Download the SVG

VectorArt.ai opens a native macOS **Save** sheet. That native sheet is outside Chrome page control, so `waitForEvent("download")` can time out even though the SVG is ready.

Use this sequence:

1. Before clicking, use Computer Use to ensure no stale **Save** sheet from an earlier download is still open. Cancel or close only a stale dialog created by this workflow.
2. Click **Download SVG** through Chrome page control.
3. Immediately switch to Computer Use for the native dialog.
4. Allow up to a few seconds for the new **Save** sheet to appear. A 400-600 ms check can still show the page; inspect again before concluding that no sheet opened.
5. Inspect Computer Use state. Chrome page control does not guarantee the Incognito window has native app focus. If another Chrome window is active, open Chrome's **Window** menu through Computer Use and select the VectorArt.ai Incognito window.
6. Confirm Computer Use now reports the native **Save** window or a `save-panel`. Do not press `Return` while a normal Chrome page is foregrounded.
7. Press `Return` through Computer Use. Do not send `Return` through Chrome page control.
8. Fetch fresh Computer Use state. If the **Save** sheet is still open, `Return` was ignored. Click the exact **Save** button from that fresh state, then verify the sheet closes. Never reuse a stale element index.
9. Verify an SVG appeared in the target folder.
10. Rename or move the downloaded generated filename to `<source-basename>.svg` using a non-destructive command.
11. Validate the file is non-empty, is detected as SVG, and passes XML parsing when `xmllint` is available.

Best-effort pseudocode for the action boundary:

```js
await tab.playwright.getByRole("button", { name: "Download SVG", exact: true }).click();
await tab.playwright.waitForTimeout(400);
// Through Computer Use, foreground the VectorArt.ai Incognito window and verify
// that the current native window is the Save sheet before continuing.
await sky.press_key({ app: "com.google.Chrome", key: "Return" });
```

While the Save sheet remains open, Chrome may hold a complete hidden file named `.com.google.Chrome.*` in the target folder. First finish or dismiss the current Save sheet. A successful **Save** action normally renames that hidden file to the generated SVG filename. Only use hidden-file recovery after confirming no current Save sheet remains. Check only files created during the current attempt; require `file` to identify the exact newest candidate as SVG and require valid XML. Never promote an older or unverified Chrome temporary file.

Do not claim success until the SVG exists in the requested folder.

## Sign out and close

Cleanup is mandatory on success and failure.

1. Dismiss any result, subscription, or error dialog when needed.
2. Open the top-navigation account/avatar menu.
3. Click **Sign out**.
4. Verify the top navigation returns to unauthenticated state.
5. Close the claimed Incognito tab. If it is the only Incognito tab, close the Incognito window.
6. Finalize Chrome tabs without keeping the workflow tab.

Treat `browser.tabs.finalize({})` as the last Chrome browser action of the turn.

## Final report

On success, report:

- source PNG
- saved SVG path
- confirmation that the account was signed out and the Incognito tab was closed

On failure, report the exact blocker and confirm cleanup. Never report an SVG download unless filesystem verification succeeded.
