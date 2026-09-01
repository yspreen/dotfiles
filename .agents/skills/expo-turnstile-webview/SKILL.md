---
name: expo-turnstile-webview
description: Use when adding Cloudflare Turnstile to Expo React Native WebViews
---

# Expo Turnstile WebView

Use this skill whenever an Expo app embeds a webpage containing Cloudflare Turnstile, or when a Turnstile widget works in Safari but fails inside an app WebView. Read [references/failure-modes.md](references/failure-modes.md) when the failure is not explained by the default allowlist fix.

This skill covers the WebView integration. It does not replace server-side Turnstile token validation. The server must still validate every token with Cloudflare Siteverify before accepting a protected action.

## Mental model

Turnstile runs inside a browser environment. A native app does not run Turnstile natively. Expo apps load it through `react-native-webview`, which adds its own navigation, storage, cookie, and JavaScript boundaries.

Safari and an in-app WKWebView are different browser contexts. Safari working proves only that the website and device can complete a browser challenge. It does not prove that the app permits Turnstile's nested frames or that the app's CSP, storage, user agent, or network path is correct.

The most common iOS failure has two independent gates:

1. `react-native-webview` applies `originWhitelist` before navigation callbacks.
2. `onShouldStartLoadWithRequest` can reject the same navigation, including a subframe navigation.

Turnstile can create nested `about:blank` and `about:srcdoc` documents. Blocking either document leaves the widget on `Verifying...` indefinitely.

## Default implementation

Use the installed Expo-compatible `react-native-webview` version. Keep the top-level page on the expected HTTPS origin. Add `about:` to the WebView whitelist because Turnstile uses internal `about:` documents:

```tsx
<WebView
  domStorageEnabled
  originWhitelist={["http://*", "https://*", "about:"]}
  sharedCookiesEnabled
  source={{ uri: protectedPageUrl }}
  thirdPartyCookiesEnabled
/>
```

The whitelist alone is not enough when the app has a navigation callback. Make the callback frame-aware:

```ts
const TURNSTILE_ORIGIN = "https://challenges.cloudflare.com";

function isTurnstileDocument(next: URL) {
  return (
    next.protocol === "about:" &&
    (next.href === "about:blank" || next.href === "about:srcdoc")
  );
}

function isAllowedNavigation(value: string, isTopFrame = true) {
  try {
    const next = new URL(value);

    if (!isTopFrame) {
      return (
        next.origin === SUPPORT_ORIGIN ||
        next.origin === TURNSTILE_ORIGIN ||
        isTurnstileDocument(next)
      );
    }

    return next.origin === SUPPORT_ORIGIN;
  } catch {
    return false;
  }
}
```

Pass the WebView event's `isTopFrame` value. `new URL("about:srcdoc").origin` is `"null"`, so compare the exact URL instead of trusting `origin` for these documents.

Do not use `originWhitelist={["*"]}` as the permanent fix. It hides the missing origin and weakens the navigation boundary. If the page legitimately has more frame origins, add those exact origins after inspecting the page's network and frame URLs.

Keep JavaScript enabled, preserve DOM storage, and avoid custom user-agent or browser-behavior changes. Do not intercept or rewrite Turnstile iframe URLs, cookies, or `postMessage` traffic.

## Triage order

Classify the failure before changing code:

1. Capture the exact page URL, app build type, platform, WebView package version, and widget mode.
2. Log `onShouldStartLoadWithRequest` URL plus `isTopFrame`. Check both `originWhitelist` and the callback.
3. Inspect the page response CSP and browser console for blocked scripts, frames, or connections.
4. Check JavaScript, DOM storage, cookies, user-agent stability, and network access to `challenges.cloudflare.com`.
5. Check sitekey hostname and server-side Siteverify failures separately from WebView loading.
6. Rebuild and install the native client. An old installed binary can make a correct source fix appear ineffective.
7. Verify on the affected platform. Never use Expo web as the native WebView test.

Use [references/failure-modes.md](references/failure-modes.md) for symptoms, checks, and fixes for each class.

## CSP

If the embedded page controls its Content Security Policy, allow Turnstile's script and frame origin:

```text
script-src https://challenges.cloudflare.com
frame-src https://challenges.cloudflare.com
```

Use a nonce-based policy when the page already uses nonces. For pre-clearance, `connect-src` must include `'self'` because Turnstile sets `cf_clearance` through the page's `/cdn-cgi/` endpoint. Add `https://challenges.cloudflare.com` to `connect-src` when the network trace shows that connection being blocked.

Inspect the actual HTTP response headers. A CSP meta tag may not describe the effective policy, and the app cannot override a policy delivered by the server.

## Verification

Use a development build or release build that matches the shipped app. Expo Go can be useful for a quick page check, but it cannot prove a custom native configuration or the final binary's WebView behavior.

Verify all of the following:

- The protected page renders inside the WebView.
- The widget leaves `Verifying...` and reaches its normal checkbox or success state.
- The state remains stable after at least 15 seconds and after one page scroll.
- Logs show `challenges.cloudflare.com` and, where used, `about:blank` or `about:srcdoc` accepted as subframes.
- The app does not allow an unexpected top-level origin.
- A submitted token is validated server-side and is rejected when missing, expired, reused, or bound to the wrong hostname/action.

Do not solve a CAPTCHA during automated verification without user confirmation. Loading the widget and observing its stable state is enough to verify the WebView plumbing. Use Cloudflare's test sitekeys for deterministic automated tests when possible.

## References

- [Cloudflare mobile implementation](https://developers.cloudflare.com/turnstile/get-started/mobile-implementation/)
- [Cloudflare Turnstile CSP guidance](https://developers.cloudflare.com/turnstile/reference/content-security-policy/)
- [Cloudflare server-side validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/)
- [react-native-webview `about:srcdoc` issue](https://github.com/react-native-webview/react-native-webview/issues/2567)
