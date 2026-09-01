# Turnstile WebView failure modes

Use this matrix after reading the main skill. Find the first symptom that matches. Confirm it with logs or a network trace before changing code.

| Symptom | Likely failure | Check | Fix |
| --- | --- | --- | --- |
| Widget stays on `Verifying...` on iOS | `about:srcdoc` or `about:blank` is rejected | Log `onShouldStartLoadWithRequest` and inspect `isTopFrame` | Add `about:` to `originWhitelist`. Allow exact `about:blank` and `about:srcdoc` URLs for subframes. |
| Widget stays on `Verifying...` after adding `originWhitelist` | App callback still rejects the frame | Temporarily log every callback return and URL | Make the callback frame-aware. Allow the support origin, `https://challenges.cloudflare.com`, and the two exact `about:` documents for non-top frames. |
| Console says `Can't open URL about:srcdoc` | WebView iOS origin filtering blocks the document | Check the WebView package behavior and whitelist | Use `originWhitelist={["http://*", "https://*", "about:"]}`. Do not reject every URL starting with `about`. |
| Widget never appears | JavaScript is disabled or a script is blocked | Check `javaScriptEnabled`, console errors, and the document CSP | Enable JavaScript. Fix the CSP or script URL. Do not inject a replacement Turnstile script. |
| Page loads but challenge frame is blank | `frame-src` or a frame navigation rule blocks Cloudflare | Inspect CSP violations and frame URLs | Permit `https://challenges.cloudflare.com` in `frame-src` and the frame callback. |
| Script loads but the challenge never completes | `connect-src` blocks challenge traffic | Inspect failed requests to Cloudflare and `/cdn-cgi/` | Permit the required Cloudflare connection. For pre-clearance, include `'self'` in `connect-src`. |
| Safari works, every app build fails | App WebView settings differ from Safari | Compare JavaScript, storage, cookies, user agent, CSP, and network | Fix the first differing WebView setting. Do not use Safari as the app verification. |
| One embedded site works and another fails | Widget mode, sitekey hostnames, CSP, or challenge path differs | Compare the two HTML responses, sitekeys, CSPs, and frame URLs | Fix the failing site's exact host/frame/CSP requirements. Do not assume all Turnstile widgets use the same frame path. |
| iOS fails but Android works | WKWebView rejects `about:` frames or iOS callback rules are too strict | Reproduce with iOS URL/callback logs | Allow the two exact internal documents and keep the callback frame-aware. Test the iOS native client. |
| Android fails but iOS works | Android cookies, cleartext rules, mixed content, or WebView settings block the challenge | Inspect Logcat, cookie settings, and HTTP/HTTPS requests | Enable DOM storage and required cookies. Prefer HTTPS everywhere. Only use Android mixed-content settings when the page truly requires them and the security impact is accepted. |
| Expo Go works but the shipped app fails | Native WebView version/configuration differs | Compare Expo Go, development build, and release build | Test the actual development or release client. Rebuild after native dependency or config changes. |
| Source fix has no effect | Old app binary or stale Metro bundle is installed | Check build timestamp/version and reinstall | Rebuild HEAD, install that artifact, restart the Simulator/device, and clear stale app data only when needed. |
| Widget passes in development but fails in release | Release CSP, hostname, minification, or native settings differ | Compare release network/console output with development | Reproduce with a release build. Verify production sitekey hostname and release page headers. |
| Widget fails only on a physical device | Device network, VPN, DNS filter, time, or device characteristics differ | Test the same URL in device Safari and inspect the device network path | Permit `challenges.cloudflare.com`, remove blocking VPN/content filters for the test, and verify device date/time. Keep the default stable user agent. |
| Widget fails only in the Simulator | Simulator network or device fingerprint is rejected, or the test uses a different architecture/build | Compare Simulator and physical-device logs | Treat Simulator as a smoke test, then confirm on a physical device. Use Cloudflare test sitekeys for deterministic automated tests. |
| Challenge restarts repeatedly | App reloads the WebView, remounts the widget, or a page script calls `reset`/`render` repeatedly | Log `onLoadStart`, `onLoadEnd`, React mounts, and Turnstile callbacks | Remove unnecessary reloads/remounts. Render once after the container exists. Reset only after an expired or consumed token. |
| Widget is invisible or clipped | Container is hidden, zero-sized, behind an overlay, or rendered before layout | Inspect computed layout and screenshot the widget area | Render in a visible container with a stable size. Do not use `display:none` during initial rendering. Re-render after a visibility transition if required. |
| Challenge appears but user interaction does nothing | Overlay, gesture handler, keyboard view, or injected script intercepts touches | Disable surrounding overlays and inspect hit testing | Keep the Turnstile frame above noninteractive overlays. Do not wrap or modify the challenge iframe. |
| Token callback fires but server rejects it | Token is missing, expired, reused, wrong hostname, or validated against the wrong secret/action | Log only a redacted Siteverify result and error category on the server | Validate immediately with the correct secret. Treat tokens as single-use and short-lived. Do not trust a client-side success callback. |
| Server accepts Safari tokens but rejects app tokens | Sitekey hostname or action does not match the embedded page | Check the page host and Siteverify `hostname`/`action` result | Register the actual production host. Use the right sitekey and expected action for that host. |
| Local HTML works without Turnstile but Turnstile fails | WebView gives the document an `about:blank` origin or an unregistered base URL | Inspect `source` and the document origin | Serve the page from its real HTTPS host, or set an explicit HTTPS `baseUrl` and register that hostname. Do not ship a secret in local HTML. |
| `onShouldStartLoadWithRequest` rejects legitimate links | Callback is a top-level policy applied to every frame or redirect | Print URL, `isTopFrame`, and the decision | Apply strict policy to top-level navigation. Apply the narrower frame policy only to subframes. Add expected redirects explicitly. |
| External links break the form | Top-level allowlist rejects a user-facing link or opens an untrusted host inside the WebView | Identify the link destination | Keep the form origin restricted. Open approved external links with the platform browser, or add a deliberate, audited destination policy. |
| HTTP page works in Safari but not Android WebView | Android blocks cleartext or mixed content | Inspect whether the document or resources use HTTP | Move the page and all Turnstile resources to HTTPS. Avoid `mixedContentMode="always"` unless there is no secure alternative. |
| Cookies disappear between screens or launches | Ephemeral/incognito store or app code clears WebView data | Check `incognito`, data-store configuration, and cleanup code | Use the default persistent data store when the flow requires it. Preserve cookies and local storage for the session. |
| Changing the user agent fixes one run and breaks the next | User agent changes during the challenge or spoofs an unsupported browser | Log the UA before load and after challenge start | Keep the platform default UA stable for the entire WebView session. Remove per-request UA changes. |
| Console shows `postMessage` origin warnings | Frame origin assumptions or injected messaging code are wrong | Inspect the sender/target origins and app-injected scripts | Do not rewrite Turnstile messages. Remove custom bridge code that intercepts them. Treat warnings as evidence only when paired with blocked frames or failed callbacks. |
| Challenge fails only behind a proxy or firewall | Cloudflare assets or connections are blocked or rewritten | Compare direct and proxied network traces | Allow the documented Cloudflare host and preserve TLS, scripts, frames, and request bodies. Do not cache or rewrite challenge responses. |
| Challenge works once, then fails on submit | Token expired or was already consumed | Check token age and whether the endpoint was called twice | Request a fresh token before retry. Validate once per submission. Make retries obtain a new token. |

## Minimal diagnostic logging

Log navigation decisions during development only. Redact query strings and never log Turnstile tokens:

```ts
onShouldStartLoadWithRequest={(request) => {
  const allowed = isAllowedNavigation(request.url, request.isTopFrame);
  if (__DEV__) {
    console.log("[webview navigation]", {
      allowed,
      isTopFrame: request.isTopFrame,
      url: request.url.split("?")[0],
    });
  }
  return allowed;
}}
```

Remove or gate this logging before release. URLs can contain user data or support context.

## Test matrix

Run the smallest matrix that covers the reported failure:

| Build | Platform | Browser context | What it proves |
| --- | --- | --- | --- |
| Development build | iOS Simulator | WebView | Fast frame and allowlist smoke test |
| Release build | iOS Simulator | WebView | Release bundle and native settings |
| Release/TestFlight build | Physical iPhone | WebView | Real WKWebView network and device behavior |
| Same device | Safari | Top-level browser | Website baseline only |
| Development/release | Android device or emulator | Android WebView | Android cookie, mixed-content, and navigation behavior |

Do not conclude that the integration works from Safari alone. Do not conclude that it works on Android when the reported failure is iOS-specific.
