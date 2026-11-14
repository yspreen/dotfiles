---
name: ios-limited-time-offer
description: Build server-controlled, hidden, time-limited iOS subscription discounts with StoreKit 2 (Tinder-style "50% off, 24h countdown" for new users via a hidden second subscription group, and one-off win-back promotional offers for existing/lapsed users with server-side eligibility and JWS signing). Use when asked for dynamic/personalized/limited-time subscription pricing, paywall-close deals, win-back offers, promo offer signatures, multiple subscription groups for pricing, or "how does Tinder do 50% off".
---

# Hidden, server-controlled subscription discounts (iOS, StoreKit 2)

Apple never lets you change a price at runtime. Every price and discount is preconfigured in App Store Connect (ASC).
"Dynamic" = your server decides which preconfigured product/offer a user is shown, and when. Two paths:

| User | Path | Mechanism |
|---|---|---|
| Never subscribed | **B. Two subscription groups** (main section) | Server assigns the user to the Standard or the Deal group. The other group stays invisible to them forever |
| Has/had a subscription | **A. One-off win-back** | Promotional offer on a product in THEIR group, eligibility + JWS signature from your server |

Promotional offers do NOT work for never-subscribed users. Apple: promo offers are for "existing and previously
subscribed customers". RevenueCat: "if it's not met users will be shown the regular product regardless". So new users
need path B.

## Why two groups (evidence)

- Settings / App Store → Subscriptions → app → **See All Plans** lists every product of the group(s) the user has
  subscribed in. The user can switch to any of them there, bypassing your app and server. Products in a group the
  user never subscribed to are not shown. Settings shows only the regular renewal price, never intro prices.
  Corroborated by 6 independent sources (none contradict, none official):
  Stack Overflow 58040335 (2019, accepted: "Users can never see the products from another subscription group");
  Apple forum 697948 (2022, accepted: "they will ONLY be shown what is within the same subscription group");
  RevenueCat holiday-sale blog (updated Nov 2025: "avoid this problem altogether by creating a new subscription
  group for each sale"); Jacob Eiting / RevenueCat CEO (2018: "you will need to create two entirely parallel
  subscription groups"); Purchasely docs ("replicate your hierarchy of subscriptions and different subscription
  groups"; "The regular price is the only one displayed in the device settings"); Tinder's sheet with exactly 15
  regular plans (Plus/Gold/Platinum × week, month, 3m, 6m, year) and no deal products, although the account saw a
  50% deal in-app. Apple's own docs only say users "see all renewal options and subscription groups" in account
  settings (ambiguous) and that switching happens within a group.
- Caveat (forum 697948): a user who once subscribed in the Deal group can resubscribe to Deal products from
  Settings forever, even after your deal window. So prefer the first-period intro variant (base = regular price):
  a lapsed Deal user resubscribing there pays full price because the intro is used up.
- Tinder 17.43.0 binary: the app asks StoreKit for extra discount product IDs next to the regular ones
  ("withDiscountProducts", "combinedProductIdentifiers", `originalProductID` for "Normally $X"). It has
  `ConflictingSubscriptionHandler` / `ConflictingSKU` errors (guard against a second group). The endpoint
  `/v3/purchase/apple/discount/eligibility` returns `discount_campaign`, `discount_percentage` and similar fields.
  UI pieces: `introPricingCountdown`, `expiresAt`, a last-hour push ("Tap to get %@% off your first month on Gold").
  For existing subscribers: "X% off your next N months" = the promotional-offer path (`PaymentDiscount` → `promotionalOffer`).

## B. Two groups: Standard + Deal (main path)

### Rules (non-negotiable)

1. **One Apple ID, one group, forever.** The first group the Apple ID ever subscribes in is its group. Never show
   products from any other group again: not after expiry, not on another device, not under another app account.
2. **Hiding works only because the user never subscribes in the other group.** One purchase in group X makes all of
   group X visible in See All Plans. So a Standard user must never buy Deal and vice versa. Each group can then have
   its own prices, intro offers, promo offers and price increases, and each stays invisible to the other cohort.
3. **Assignment is free until the first purchase.** A never-subscribed user can be moved between Standard and Deal
   (deal starts, deal expires). After the first purchase the group is locked (rule 1).
4. **Apple ID history beats your account data.** Settings shows groups by Apple ID, and intro eligibility is per
   Apple ID per group. Read the group from `Transaction.all` on device and send it to the server. If your account and
   the Apple ID disagree, the Apple ID group wins.
5. **Never allow two active groups.** Separate groups can bill at the same time. Before every purchase, block if
   `Transaction.currentEntitlements` has an active subscription in another group.
6. **Same entitlement for both groups.** Map `pro_*` and `pro_deal_*` to the same features.

### App Store Connect clicks

1. **Standard group:** Apps → app → sidebar **Subscriptions** → (+) Subscription Group, Reference Name `Pro`.
   (+) products `pro_monthly`, `pro_yearly`. Set the regular prices. Order the levels. Optionally add an intro trial.
   Group localization (display name shown in Settings): "Pro".
2. **Deal group:** (+) Subscription Group, Reference Name `Pro Deal`, **same display name "Pro"** (users see it in
   Settings once subscribed). Mirror every tier/duration you sell: `pro_deal_monthly`, `pro_deal_yearly`, same levels.
   Pick the discount:
   - **First period only (Tinder):** base price = regular, then **Subscription Prices (+) → Set Up Introductory Offer**
     → Pay as you go (N months) or Pay up front (1 year) at 50%, all storefronts. Apple applies it automatically to
     anyone who never used an intro in THIS group, which with rule 1 is every Deal user.
   - **Permanent discount:** base price = 50% of regular. Renewals stay cheap forever. Safe, because only Deal users
     can ever see this group.
3. **More variants:** one more group per variant (`Pro Deal 30`, `Pro Deal 50`, `Pro Deal Weekly`, ...). The server
   picks the group. ASC documents no small group limit; keep it manageable.
4. **Per product, both groups:** localization (display name "Pro Monthly", identical in both groups), review
   screenshot. Turn off **Promote In-App Purchase** for every deal product.
5. **Review:** new subscriptions ship with an app version. Review Notes: "Pro Deal products appear after dismissing
   the paywall once on a fresh account."
6. **In-App Purchase key** (also needed for path A): Users and Access → Integrations → **In-App Purchase** tab → (+)
   Generate. Download the `.p8` (only possible once). Copy the Key ID and the Issuer ID. Use the In-App Purchase key,
   NOT an App Store Connect API key.

### Server

User record: `{ userId, lockedGroup?, assignedGroup, dealExpiresAt?, lastDealAt?, appAccountToken }`.

`POST /plans` with `{ historyGroupID?, hasActiveSub, appTransactionID? }`. It returns
`{ group, productIDs, deal?: { expiresAt, percent }, winback?: {...} }`:

```ts
const GROUPS = { standard: { id: "<ASC group id>", products: ["pro_monthly", "pro_yearly"] },
                 deal50:   { id: "<ASC group id>", products: ["pro_deal_monthly", "pro_deal_yearly"] } };

function plansFor(u: User, req: PlansReq, now = Date.now()) {
  // Rule 1 + 4: Apple ID history locks the group forever
  const locked = req.historyGroupID ? groupKeyById(req.historyGroupID) : u.lockedGroup;
  if (locked) return { group: locked, productIDs: GROUPS[locked].products, winback: winbackFor(u, req, now) };
  // Rule 3: never subscribed → free assignment
  const dealOpen = u.dealExpiresAt && now < u.dealExpiresAt;
  const g = dealOpen ? "deal50" : "standard";
  return { group: g, productIDs: GROUPS[g].products, deal: dealOpen ? { expiresAt: u.dealExpiresAt, percent: 50 } : undefined };
}

// POST /deal/trigger, called on paywall dismiss. Never-subscribed users only. Never reset a running timer.
function triggerDeal(u: User, req: PlansReq, now = Date.now()) {
  if (req.historyGroupID || u.lockedGroup || req.hasActiveSub) return;
  if (u.dealExpiresAt && now < u.dealExpiresAt) return;                      // already running
  if (u.lastDealAt && now - u.lastDealAt < 90 * 864e5) return;               // cooldown
  u.dealExpiresAt = now + 24 * 36e5; u.lastDealAt = now;
}
```

On every verified purchase (client sync or App Store Server Notifications V2), set `lockedGroup` from the
transaction's `subscriptionGroupIdentifier` if it is unset. Never overwrite it.

**Deal window vs. hard enforcement:** the countdown is enforced by the server no longer returning the deal group.
A tampered client could still buy a deal product after expiry (the product exists in the store). Accept that, or
in your purchase-sync handler flag deal purchases made after `dealExpiresAt`.

### Swift client

```swift
import StoreKit
import SwiftUI

struct Plans: Decodable {
    struct Deal: Decodable { let expiresAt: Date; let percent: Int }
    let group: String; let productIDs: [String]; let deal: Deal?; let winback: Winback?
}

/// Rule 4: the subscription group this Apple ID ever subscribed in (nil = never subscribed)
func historyGroupID() async -> String? {
    var latest: Transaction?
    for await result in Transaction.all {
        if case .verified(let t) = result, t.subscriptionGroupID != nil,
           t.purchaseDate > (latest?.purchaseDate ?? .distantPast) { latest = t }
    }
    return latest?.subscriptionGroupID
}

/// Rule 5: block buying in group X while a sub in another group is active
func hasActiveSub(outside groupID: String) async -> Bool {
    for await result in Transaction.currentEntitlements {
        if case .verified(let t) = result, let g = t.subscriptionGroupID, g != groupID, t.revocationDate == nil { return true }
    }
    return false
}

func buy(_ product: Product, accountToken: UUID, extra: Set<Product.PurchaseOption> = []) async throws -> Transaction? {
    guard let group = product.subscription?.subscriptionGroupID,
          await !hasActiveSub(outside: group) else { return nil }
    switch try await product.purchase(options: extra.union([.appAccountToken(accountToken)])) {
    case .success(.verified(let t)): await t.finish(); return t   // then sync to server → lockedGroup
    default: return nil                                             // .userCancelled, .pending, unverified
    }
}
```

Paywall flow:
1. On paywall appear: `POST /plans {historyGroupID, hasActiveSub}`, then `Product.products(for: plans.productIDs)`.
   Show ONLY those products. Never hardcode product IDs of other groups in UI code paths.
2. Price label for the deal group: `product.subscription?.introductoryOffer?.displayPrice` (first-period variant) or
   `product.displayPrice` (permanent variant). Compare against the Standard price the server sends for "Normally $X".
   Also check `await product.subscription?.isEligibleForIntroOffer`. It should always be true by rule 1; if false,
   do not advertise the discount.
3. Countdown: `Text(plans.deal!.expiresAt, style: .timer)`. Hide the deal UI at `expiresAt` and refetch `/plans`.
4. On user dismiss (not after a purchase): `POST /deal/trigger`, then refetch `/plans`.
5. Optional last-hour push: schedule a local notification at `expiresAt - 3600`.

## A. One-off win-back for existing/lapsed users (server eligibility)

The user stays in their locked group. Create the offer on the products of EACH group (a Standard user's offer must
be on `pro_*`, a Deal user's on `pro_deal_*`). Promotional offers never appear in Settings and only apply with your
JWS, so they cannot leak.

**ASC:** Subscriptions → group → product → **Subscription Prices (+)** → **Create Promotional Offer** → Reference Name
+ **Promotional Offer Identifier** (e.g. `winback50_1y`, the `offerID` in code) → Pay up front / Pay as you go / Free,
duration, 50% price → review per-storefront prices → **Confirm**. Max 10 active offers per product. Only the price is
editable later. Up to 1h until sandbox sees changes. Role: Account Holder, Admin, App Manager or Marketing.

**Server eligibility:** you decide everything. Example `winbackFor`: user has history, no active sub, lapsed ≥ 30
days, never redeemed this winback, ≤ 1 offer per 180 days. Return `{ productID (in their group), offerID, expiresAt }`.
`POST /winback/sign` at tap time: auth + rate limit, re-check eligibility and `now < expiresAt`, return the JWS.
Sign at tap, never at display: Apple derives the JWS expiry from `iat` and does not document the window.

JWS (Apple "Generating JWS to sign App Store requests"): header `{alg: ES256, kid: <Key ID>, typ: JWT}`, payload
`{iss: <Issuer ID>, iat, aud: "promotional-offer", bid, nonce: <uuid>, productId, offerIdentifier, transactionId?}`.
**No `exp`** (request fails). `transactionId` is optional but recommended: use the customer's `appTransactionID`.

```ts
import { SignJWT, importPKCS8 } from "jose"; // Node, Cloudflare Workers, Convex actions

export async function signPromo(env: Env, productId: string, offerIdentifier: string, transactionId?: string) {
  const key = await importPKCS8(env.IAP_KEY_P8, "ES256");
  return new SignJWT({ bid: env.BUNDLE_ID, nonce: crypto.randomUUID(), productId, offerIdentifier,
                       ...(transactionId && { transactionId }) })
    .setProtectedHeader({ alg: "ES256", kid: env.IAP_KEY_ID, typ: "JWT" })
    .setIssuer(env.IAP_ISSUER_ID).setIssuedAt().setAudience("promotional-offer")
    .sign(key);
}
```
Official equivalent: `@apple/app-store-server-library` →
`new PromotionalOfferV2SignatureCreator(p8, keyId, issuerId, bundleId).createSignature(productId, offerIdentifier, transactionId)`.

**Swift:** `promotionalOffer(_:compactJWS:)` returns `[Product.PurchaseOption]` (an array). Available from iOS 15,
back-deployed; build with the iOS 26 SDK. The older `promotionalOffer(offerID:keyID:nonce:signature:timestamp:)`
(Tinder uses it) needs the legacy ECDSA signature.

```swift
struct Winback: Decodable { let productID: String; let offerID: String; let expiresAt: Date }

func appTransactionID() async -> String? {
    guard case .verified(let app)? = try? await AppTransaction.shared else { return nil }
    return app.appTransactionID
}

func buyWinback(_ w: Winback, product: Product, token: UUID, sign: (Winback) async throws -> String) async throws -> Transaction? {
    guard Date() < w.expiresAt else { return nil }
    let jws = try await sign(w)                                     // POST /winback/sign at tap time
    return try await buy(product, accountToken: token,
                         extra: Set(Product.PurchaseOption.promotionalOffer(w.offerID, compactJWS: jws)))
}
// Price label: product.subscription?.promotionalOffers.first { $0.id == w.offerID }?.displayPrice
```

Errors (`Product.PurchaseError`): `.ineligibleForOffer` (no sub history in this group), `.invalidOfferSignature`
(wrong key/kid/iss/bid or JWS too old: re-sign once), `.invalidOfferIdentifier`, `.invalidOfferPrice`,
`.missingOfferParameters`. Redemption on device: `transaction.offer?.type == .promotional` (iOS 17.2+). Server:
App Store Server Notifications V2 carry `offerType` + `offerIdentifier`.

## Testing

- Xcode StoreKit config file: model both groups. `Product.PurchaseOption.promotionalOffer(id:)` is an
  Xcode-testing-only option that needs no signature.
- Sandbox: one fresh sandbox Apple Account per cohort (Standard, Deal). After a deal purchase, check Settings →
  Developer → Sandbox Apple Account → Manage → Subscriptions → See All Plans: only deal-group plans may appear.
- Lapsed state: cancel there and wait for expiry (sandbox periods last minutes). Then test path A.
- ASC offer/price changes take up to 1h to reach sandbox.

## Pitfalls

- Deal products in the Standard group → visible to every subscriber in See All Plans. Always a separate group.
- Showing a Deal-group product to someone with Standard history (or vice versa) → their second group becomes
  visible, two subscriptions can run, and a lapsed Standard user counts as new for Deal intro offers. Rule 1.
- Resetting the 24h timer on every dismiss → fake urgency, App Review risk. One real deadline per user.
- Promo JWS for a never-subscribed user → full-price sheet. Promo offers are path A only.
- Signing at display time → buyable after the countdown. Sign at tap.
- `.p8` in the app binary → anyone can mint offers. Key lives only on the server.
- Group display names differ ("Pro Deal") → users see the word "Deal" in Settings. Use the same display names.

Sources: developer.apple.com/documentation/storekit/generating-jws-to-sign-app-store-requests;
.../product/purchaseoption/promotionaloffer(_:compactjws:); .../introductoryoffereligibility(compactjws:);
developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-promotional-offers-for-auto-renewable-subscriptions;
revenuecat.com/docs/subscription-guidance/subscription-offers/ios-subscription-offers;
stackoverflow.com/questions/58040335; github.com/apple/app-store-server-library-node (jws_signature_creator.ts);
Tinder 17.43.0 IPA strings + real "Available Plans" sheet.
