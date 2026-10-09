# MIGA Mobile — منصة الشراء الجماعي

Three Flutter apps on one design system, all talking to the MIGA API. Arabic-first (RTL), brand red `#C4011A`.

```
mobile/
├── packages/
│   ├── miga_core/        # Enums (same numeric values as Miga.Domain), models, API layer (src/api),
│   │                     # sample data for the design gallery
│   └── miga_ui/          # Design system: theme per role, Tajawal font (bundled), images, widgets
│                         # (buttons, inputs, chips, campaign progress, timeline, bar chart, wizard,
│                         # auth pages, splash/onboarding, states, notifications)
└── apps/
    ├── miga_customer/    # ميجا            — العميل
    ├── miga_merchant/    # ميجا للتجار     — التاجر
    ├── miga_driver/      # ميجا كابتن      — المندوب
    └── miga_admin/       # لوحة الإدارة القديمة (Flutter Web) — استُبدلت بـ admin-web/ (React)
```

Requirements: Flutter 3.29+ / Dart 3.7+. iOS needs `pod install` after dependency changes; after changing
`miga_core` / `miga_ui` dependencies run `flutter pub get` in each app.

## Run against the API

```bash
# terminal 1 — XAMPP MySQL running; Development seeds demo data
cd backend && dotnet run --project src/Miga.Api --launch-profile http
# terminal 2 — the OTP screen shows the dev code returned by the server
cd mobile/apps/miga_customer && flutter run
```

Skip the login on development servers (signs in with the server's dev code):

| App | Command | Demo account |
|---|---|---|
| Customer | `flutter run --dart-define=MIGA_DEV_PHONE=0559990001` | any new number works too |
| Merchant | `flutter run --dart-define=MIGA_DEV_PHONE=0511111111` | verified, 4 stores, 12 products, 8 campaigns |
| Driver | `flutter run --dart-define=MIGA_DEV_PHONE=0522222222` | verified, online, Riyadh |

Base URL: `http://localhost:5296` (iOS simulator) / `http://10.0.2.2:5296` (Android emulator); override with
`--dart-define=MIGA_API_URL=https://…`.

### API layer (`miga_core/lib/src/api`)

`ApiClient` — JSON, bearer token, single-flight refresh on 401 (then `onSessionExpired` → login), Arabic
`ApiException` messages, multipart image upload (`POST /api/uploads/{folder}`). Tokens live in the iOS Keychain /
Android Keystore. `MigaApi` groups typed endpoints: `auth`, `catalog`, `customer`, `merchant`, `driver`,
`notifications`.

### The order flow across the three apps

1. **Customer** joins a campaign and pays. When the target quantity is reached the campaign completes and one
   aggregated order goes to the merchant.
2. **Merchant** confirms → prepares → marks it *Ready*; the order screen then shows a **pickup code** and drivers in
   the store's city get a request.
3. **Driver** accepts a delivery, enters the merchant's pickup code at the warehouse, starts the trip, and finishes by
   entering the **delivery code** the customer sees in their order.
4. When every delivery is done the merchant's net amount moves from *pending settlement* to *available* in the wallet.

Not in the API yet, so not in the apps: regular (non-campaign) product orders (checkout returns them as
`product_orders_unsupported`), driver payouts, sharing links, store following, and a support channel.

## Admin dashboard (web)

> **Superseded** by the React dashboard in [`admin-web/`](../admin-web/README.md). This Flutter Web app is kept for
> reference until it is removed.

```bash
cd mobile/apps/miga_admin
flutter run -d chrome --dart-define=MIGA_DEV_PHONE=0500000000   # dev: signs in as the seeded admin
# or a static build
flutter build web --no-web-resources-cdn && python3 -m http.server 8090 --directory build/web
```

Sections: dashboard (alerts, 30-day sales and commission, 14-day chart, top stores), verification queue (approve /
reject with a reason the user sees), customers / merchants / drivers (search, filters, details panel, suspend /
reactivate), campaigns (cancel → automatic refunds), customer and aggregated orders, deliveries (retry a failed one with
the same driver, or refund the customer) and merchant withdrawals (record the bank reference, or reject back to the
balance). Links: `?section=merchants`, `?section=deliveries`, … and `&user=<id>` opens an account's panel.

Only numbers that are already admins can sign in (`userType: 4`). The API allows any `localhost` origin in Development
(CORS); production origins go in `Cors:Origins`. Add `--pwa-strategy=none` to builds you reload often, otherwise the
service worker keeps serving the previous version.

## Tests

```bash
cd mobile/packages/miga_core && flutter test    # models, enums ↔ backend, live API contract (skipped if the API is down)
cd mobile/packages/miga_ui   && flutter test    # formatting
cd mobile/apps/miga_customer && flutter test    # splash → onboarding, shell renders (same for merchant/driver)
```

The live contract test signs in as the demo accounts; the server allows one OTP per phone every 60 s, so wait a minute
before running it twice.

## Design review shortcuts

Open a screen directly with `flutter run --dart-define=MIGA_SCREEN=<name>` (combine with `MIGA_DEV_PHONE` for screens
that need a signed-in user):

| App | Screens |
|---|---|
| Customer | `login` `profile` `home` `campaigns` `ending` `categories` `search` `cart` `orders` `account` `checkout` `addresses` `add_address` `pay_success` `pay_failed` `offline` `gallery` |
| Merchant | `login` `wizard` `pending` `home` `campaigns` `products` `orders` `more` `product_new` `categories` `stores` `store_new` `campaign_new` `earnings` `order_detail` `gallery` |
| Driver | `login` `wizard` `pending` `home` `deliveries` `earnings` `account` `delivery` `gallery` |

Extra flags: `MIGA_ORDER_ID=<guid>` (merchant `order_detail`), `MIGA_DELIVERY_ID=<guid>` (driver `delivery`),
`MIGA_ONB_PAGE=2` (onboarding page), `MIGA_WIZARD_STEP=1` (registration / campaign wizard step), `MIGA_SCROLL=700`
(start scrolled), `MIGA_PAY_FAIL=true` (checkout uses the mock gateway's failing card).

## Images

All images live in `packages/miga_ui/assets/images/` and load with `MigaImage('file.png')`; paths starting with
`/uploads/` or `http` load from the API. A missing file shows a branded placeholder. Prompts used to produce them:
`../docs/IMAGE_PROMPTS.md`.
