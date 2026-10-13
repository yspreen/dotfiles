---
name: chrome
description: A fallback for bypassing issues in the browser skill. The chrome skill is working with a real browser with the users full session data, cookies, auth. It's not headless so you can use chrome to bypass captchas and automation detection that the browser skill can run into
---

You can run actions to interface with Chrome like this command:
`codex --yolo --model=$model -c model_reasoning_effort="low" e "/chrome Please list the user's open tabs" 2>/dev/null`

where `$model` can be one of:
gpt-5.6-terra
gpt-5.6-sol

and `Please list the user's open tabs` is an example action.

Default to Terra. Sol is only intended for tricky tasks. Normal browsing, page reading, tab management, and form interaction should use Terra.

There's no concept of past commands here. Each execution starts with a blank slate. So saying something like "Please re-open that url" won't make any sense to the chrome interface agent. Each command is stateless. Only the chrome browser itself has state.

Tell Codex what to do with the `/chrome` prefix. The Chrome plugin controls the user's existing Chrome session and can use open tabs, logged-in sessions, and installed extensions.

## Browser connection

Chrome plugin can:

- List available browser connections.
- Connect to Chrome through the extension connection.
- Read Chrome API documentation.
- Name the current automation session.
- List and inspect optional capabilities exposed by the current connection.

Underlying commands include:

- `agent.browsers.list()`
- `agent.browsers.get("extension")`
- `chrome.documentation()`
- `chrome.nameSession("name")`
- `chrome.capabilities.list()`
- `chrome.capabilities.get(id)`

## User Chrome state

- List the user's open tabs across Chrome windows.
- Claim an existing user tab so the session can control it.
- Read browsing history.
- Filter history by:
  - Start time
  - End time
  - Maximum results
  - Search queries
- History results can include URL, page title, and visit timestamp.

Underlying commands:

- `chrome.user.openTabs()`
- `chrome.user.claimTab(tab)`
- `chrome.user.history(options)`

The plugin does not expose cookies, passwords, local storage, browser profiles, or session stores.

## Tab management

- List tabs controlled by the current session.
- Get the selected controlled tab.
- Retrieve a controlled tab by ID.
- Open a new tab.
- Close a tab.
- Clean up session-created tabs while choosing whether to keep them.

Underlying commands:

- `chrome.tabs.list()`
- `chrome.tabs.selected()`
- `chrome.tabs.get(id)`
- `chrome.tabs.new()`
- `tab.close()`
- `chrome.tabs.finalize({ keep })`

Tab navigation:

- `tab.goto(url)`
- `tab.reload()`
- `tab.back()`
- `tab.forward()`
- `tab.url()`
- `tab.title()`

No direct commands for:

- Pinning or reordering tabs
- Moving tabs between windows
- Creating or editing tab groups
- Switching Chrome windows directly
- Renaming tabs

## Page inspection

- Inspect visible DOM and accessible page structure.
- Capture viewport or full-page screenshots.
- Run read-only JavaScript against the page DOM.
- Read captured console logs.
- Inspect active JavaScript dialogs.

Underlying commands:

- `tab.playwright.domSnapshot()`
- `tab.screenshot(options)`
- `tab.playwright.evaluate(...)`
- `tab.dev.logs(options)`
- `tab.getJsDialog()`

Screenshot options include:

- `fullPage`
- `clip`

Console-log filters include:

- `filter`
- `levels`
- `limit`

## Searching

There is no dedicated `chrome.search()` command.

Search by telling Codex to:

- Navigate to Google, Bing, or another search engine.
- Fill the search field and submit it.
- Read search results.
- Open a result.
- Navigate directly to a known search URL.
- Search visible content on the current page using DOM inspection or the site's search controls.

Examples:

```text
/chrome Search Google for the latest Chrome extension API documentation and summarize the first five results
```

```text
/chrome Search the current page for references to WebSockets
```

## Page interaction

Chrome supports Playwright-style semantic locators:

- `getByRole(role, options)`
- `getByLabel(text, options)`
- `getByPlaceholder(text, options)`
- `getByText(text, options)`
- `getByTestId(testId)`
- `locator(selector)`
- `frameLocator(selector)`

Locator inspection:

- `count()`
- `isVisible()`
- `isEnabled()`
- `innerText()`
- `textContent()`
- `getAttribute(name)`
- `allTextContents()`
- `all()`
- `evaluate(...)`

Locator actions:

- `click()`
- `dblclick()`
- `fill(value)`
- `type(value)`
- `press(key)`
- `check()`
- `uncheck()`
- `setChecked(value)`
- `selectOption(value)`
- `waitFor(options)`

Supported tasks include:

- Click buttons and links.
- Fill and submit forms.
- Type into fields.
- Press keyboard keys.
- Select dropdown options.
- Check and uncheck boxes.
- Double-click.
- Scroll.
- Interact with iframes.
- Read visible text and attributes.
- Inspect page state after actions.
- Take screenshots.
- Read console errors and logs.

## Coordinate and visual interaction

`tab.cua` supports mouse and keyboard control:

- `click({ x, y })`
- `double_click({ x, y })`
- `drag({ path })`
- `move({ x, y })`
- `scroll({ x, y, scrollX, scrollY })`
- `keypress({ keys })`
- `type({ text })`

`tab.dom_cua` supports DOM-node interaction:

- `get_visible_dom()`
- `click({ node_id })`
- `double_click({ node_id })`
- `keypress({ keys })`
- `type({ text })`
- `scroll({ node_id, x, y })`

Use these when normal semantic locators fail.

## Downloads

Chrome can trigger and wait for browser downloads:

- `tab.playwright.waitForEvent("download")`
- `locator.downloadMedia()`

Limits:

- No documented command chooses the downloaded filename.
- No documented command reads a completed download directly from the download object.
- No general Chrome Downloads-page management API exists.
- Download permission prompts may require confirmation.
- The plugin can inspect download links and trigger downloads when appropriate.

## File uploads

Chrome can upload local files through file chooser controls:

- `tab.playwright.waitForEvent("filechooser")`
- `fileChooser.isMultiple()`
- `fileChooser.setFiles(path)`

Uploading transmits local data to a website. Only upload files when the user clearly authorizes the destination and files.

## Clipboard

- `tab.clipboard.read()`
- `tab.clipboard.readText()`
- `tab.clipboard.write(items)`
- `tab.clipboard.writeText(text)`

Clipboard items can contain MIME type, text, base64 binary data, and presentation style.

## Dialogs

Supported dialogs:

- Alert
- Confirm
- Prompt
- Before-unload

Actions:

- `dialog.dismiss()`
- `dialog.accept()`
- `dialog.accept(text)` for prompts

## Waiting and navigation events

- `waitForEvent("download")`
- `waitForEvent("filechooser")`
- `waitForLoadState()`
- `waitForURL(url)`
- `waitForTimeout(milliseconds)`
- `expectNavigation(action, options)`

Supported load states:

- `commit`
- `domcontentloaded`
- `load`
- `networkidle`

## Optional page capabilities

Optional capabilities vary by Chrome connection. Discover them before use:

```js
await tab.capabilities.list()
await (await tab.capabilities.get("pageAssets")).documentation()
```

One documented capability is `pageAssets`, which can list observed page assets and bundle selected assets into a temporary local artifact.

## Bookmarks

No dedicated bookmarks API is exposed.

Cannot directly:

- List bookmarks.
- Create bookmarks.
- Edit bookmark names or URLs.
- Delete bookmarks.
- Organize bookmark folders.

Codex may be able to interact with visible Chrome bookmark UI when that UI is exposed to the controlled page, but this is not a guaranteed plugin capability.

## Unsupported Chrome state and settings

No dedicated APIs for:

- Extensions management
- Chrome settings
- Autofill
- Saved passwords
- Payment methods
- Cookies
- Cache
- Permissions management
- Downloads history
- Browser profile switching
- Incognito-window management
- Browser window resizing
- Installing extensions

## External effects and confirmation

Reading pages, listing tabs, reading history, inspecting DOM, reading logs, and taking screenshots are normally read-only.

Actions with external effects include:

- Sending or submitting forms
- Uploading files
- Downloading files
- Purchases
- Posting messages or content
- Changing account or site settings
- Changing permissions
- Installing software or extensions
- Saving passwords or payment methods
- Accepting camera, microphone, location, download, or login permissions
- Deleting meaningful data

Require explicit instruction or confirmation before consequential external effects unless the user's request already clearly authorizes the exact action.

## Plugin status

Chrome connector surface covers:

- Existing Chrome tabs and logged-in sessions
- Tab creation, selection, navigation, and closing
- Browsing history
- DOM and accessibility inspection
- Screenshots
- Website search through normal page interaction
- Form filling and controls
- Mouse and keyboard interaction
- Iframes
- Downloads and uploads
- Clipboard
- JavaScript dialogs
- Console logs
- Optional page assets

It does not provide dedicated bookmark, cookie, password, Chrome settings, extension-management, tab-group, or downloads-history APIs.
