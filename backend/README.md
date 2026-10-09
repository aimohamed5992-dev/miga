# MIGA Backend — ASP.NET Core + MySQL (XAMPP) + Pomelo

```
backend/
├── Miga.slnx
└── src/
    ├── Miga.Domain/          # Entities + enums (enum values shared with the Flutter apps)
    ├── Miga.Infrastructure/  # MigaDbContext (Identity, Guid keys), Fluent configurations, migrations, seeder
    └── Miga.Api/             # ASP.NET Core Web API (controllers, OpenAPI)
```

Stack: .NET 10 · EF Core 9 · Pomelo.EntityFrameworkCore.MySql 9.0.0 · ASP.NET Core Identity · MariaDB 10.4 (XAMPP).

## Run

1. Start **MySQL** from the XAMPP control panel (root, empty password, port 3306).
2. Run the API — in Development it applies migrations and seeds reference data automatically:

```bash
cd backend
dotnet run --project src/Miga.Api --launch-profile http
curl http://localhost:5296/api/health
```

Connection string: `src/Miga.Api/appsettings.json` → `ConnectionStrings:Miga` (database `miga_db`, utf8mb4).

## Migrations

```bash
dotnet ef migrations add <Name> -p src/Miga.Infrastructure -s src/Miga.Api -o Persistence/Migrations
dotnet ef database update      -p src/Miga.Infrastructure -s src/Miga.Api
```

## Data model (summary)

`ApplicationUser` (Identity, roles Customer/Merchant/Driver/Admin) → Customer/Merchant/Driver profiles ·
`Region → City → District → Address` · `StoreCategory`, `Merchant → Store → ProductCategory (parent/child) → Product → ProductImage` ·
`Campaign` (group buying) → `CampaignOrder` (+ `Payment`) per customer → on completion one `MerchantOrder` → `Delivery` per customer ·
`Cart → CartItem` (product or campaign) · `OtpCode`, `Notification`.

## Authentication (phone + OTP → JWT)

| Endpoint | Who | Purpose |
|---|---|---|
| `POST /api/auth/send-otp` `{phone}` | anyone | 4-digit SMS code (5 min). 60s resend cooldown, 5 sends / 30 min. In Development `devCode` is returned. |
| `POST /api/auth/verify-otp` `{phone, code, userType}` | anyone | Creates the account on first sign-in; returns `accessToken` (60 min) + `refreshToken` (30 days) + `account`. 5 wrong tries lock the code. One account type per phone. |
| `POST /api/auth/refresh` `{refreshToken}` | anyone | Rotates: old refresh token is revoked. |
| `POST /api/auth/logout` `{refreshToken}` | anyone | Revokes the refresh token. |
| `GET /api/auth/me` | signed in | `isProfileComplete`, `verificationStatus` (`not_submitted` / `pending` / `verified`). |
| `PUT /api/customer/profile` | Customer | Full name + optional email. |
| `POST /api/merchant/register` | Merchant | Business info + first store (inactive until verified). |
| `POST /api/driver/register` | Driver | Personal + vehicle info, work city. |
| `POST /api/auth/verify-otp` with `userType: 4` | — | Admin dashboard sign-in; only numbers that are already admins (`Seed:AdminPhone`, dev: 0500000000) — never creates accounts. |
| `GET /api/regions`, `GET /api/store-categories` | anyone | Reference data. |

`userType`: 1 Customer · 2 Merchant · 3 Driver. Phones are accepted as `05…`, `5…`, `+9665…`, `009665…` or Arabic digits and stored as `+9665XXXXXXXX`.

Errors are ProblemDetails with an Arabic `title` and a stable `code`, e.g.
`{"status":400,"title":"الرمز غير صحيح، حاول مرة أخرى","code":"otp_invalid"}`.

Secrets: `Jwt:Key` (≥ 32 chars) and `Otp:Secret` are empty in `appsettings.json`; Development values live in
`appsettings.Development.json`. For production use environment variables / user-secrets.
SMS goes through `ISmsSender` (currently logs the message) — plug in a provider (Unifonic, Taqnyat…).

## Tests

```bash
dotnet test   # integration tests against miga_test_db on XAMPP (dropped & re-created each run)
```

## Catalog, addresses & merchant management

**Customer — addresses** (`Customer` role): `GET/POST /api/customer/addresses`, `GET/PUT/DELETE /api/customer/addresses/{id}`,
`POST /api/customer/addresses/{id}/default`. District must belong to the city and the city to the region; the first address is
the default; deleting the default promotes the next one; deletes are soft so past orders keep their address.

**Public browsing** (no sign-in): `GET /api/home` · `GET /api/campaigns?sort=newest|endingSoon|almostComplete|biggestDiscount&storeId=&storeCategoryId=&q=&page=` ·
`GET /api/campaigns/{id}` · `GET /api/stores?categoryId=&q=` · `GET /api/stores/{id}` · `GET /api/stores/{id}/categories` ·
`GET /api/stores/{id}/products?categoryId=&q=` · `GET /api/products/{id}` · `GET /api/search?q=`.
Only verified, active stores are visible; live campaigns = `Active` and inside their date window.

**Merchant** (`Merchant` role, ownership checked): `/api/merchant/stores` (CRUD + `PATCH {id}/active`),
`/api/merchant/stores/{storeId}/categories` (2 levels; a category with live products can't be deleted; one that only
held deleted products is archived), `/api/merchant/stores/{storeId}/products` (CRUD, ordered images, `PATCH …/active`,
soft delete; blocked while the product is in a running campaign).

**Uploads**: `POST /api/uploads/{products|stores|documents|deliveries|avatars}` (multipart `file`, JPG/PNG/WEBP ≤ 5 MB,
content-sniffed) → `{ "url": "/uploads/…" }`. Files live in `src/Miga.Api/wwwroot/uploads`.

**Demo data** (Development, `Seed:DemoData=true`): merchant `0511111111` with 4 stores, 12 products and 8 campaigns,
and a verified, online driver `0522222222` in Riyadh (seeded separately, so it is added to existing databases too).

> MariaDB 10.4 note: avoid `COUNT(DISTINCT …)` inside correlated subqueries and `array.Contains` in LINQ (C# 14 binds it to
> spans, which EF Core 9 can't translate) — use counts of rows and `List<T>.Contains`.

## Cart, checkout & campaign lifecycle

| Endpoint (Customer) | |
|---|---|
| `GET /api/customer/cart` | Lines grouped by store, totals, savings, per-line `issue` (`campaign_ended` / `unavailable` / `price_changed`). |
| `POST /api/customer/cart/items` `{productId, campaignId?, quantity}` | Adds or merges; checks campaign is live, per-customer max, remaining quantity, not already joined. |
| `PATCH /api/customer/cart/items/{id}` `{quantity}` · `DELETE …/{id}` · `DELETE /api/customer/cart` | |
| `POST /api/customer/checkout` `{addressId, paymentMethod, cartItemIds?}` | Each campaign line succeeds/fails on its own → `items[]`, `totalCharged`. Methods: `mada`, `applepay`, `card`, `stcpay` (`test_fail` = declined). |
| `GET /api/customer/orders?scope=current\|past` · `GET /api/customer/orders/{id}` | Status, campaign progress, payment, delivery (driver + delivery code), `canCancel`. |
| `POST /api/customer/orders/{id}/cancel` `{reason}` | Only while the campaign is still collecting → full refund, quantity released. |
| `GET /api/notifications` · `POST /api/notifications/read-all` | Any signed-in user. |

**How joining a campaign stays correct under load** — per campaign line, in one transaction:
`SELECT … FOR UPDATE` on the campaign row → check live / remaining / per-customer limit / one order per customer →
charge → order `Paid` → `CurrentQuantity += qty` → if the target is reached: campaign `Completed`, orders `Confirmed`,
one `MerchantOrder` (total qty, customers, 5% platform fee, pickup code) and one `Delivery` per customer (delivery code),
stock deducted, everyone notified. Verified by a test where 6 buyers race for 3 pieces: exactly 3 succeed.

**Expiry**: `CampaignExpiryWorker` runs every minute (`Jobs:*`): past-due campaigns that didn't fill become `Failed`
and every paid order is refunded (+ notifications).

**Payments**: `IPaymentGateway` with `MockPaymentGateway` (instant). A real provider (Moyasar / HyperPay / Tap) adds a
redirect + webhook; orders would then wait as `Pending` with a short reservation.

**Not yet supported**: buying a regular product outside a campaign — checkout reports those lines as
`product_orders_unsupported` (needs the generic `Order/OrderItem` model the spec mentions for a later version).

## Merchant campaigns, aggregated orders & wallet

All under `/api/merchant`, `Merchant` role, ownership enforced.

| Endpoint | |
|---|---|
| `GET dashboard?storeId=` | Last 7 days sales, week vs previous week, active campaigns, orders in progress, participants, products, orders needing action. |
| `GET campaigns?tab=active\|done\|ended\|draft` · `GET campaigns/{id}` · `GET campaigns/{id}/participants` | Participants are masked (`محمد ع.`) with district, quantity, amount. |
| `POST campaigns` (`publish: false` = draft) · `PUT campaigns/{id}` (drafts only) · `POST campaigns/{id}/publish` | Rules: price < original, target ≥ 2 and ≤ stock, max/customer ≤ target, 1–30 days, store verified & active, **one live campaign per product**. |
| `POST campaigns/{id}/extend {days}` | 1–14 days, total ≤ 60; participants notified. |
| `POST campaigns/{id}/cancel {reason}` | Every paid order refunded + notified. |
| `GET orders?tab=new\|preparing\|ready\|done` · `GET orders/{id}` | Detail: totals, 5% fee, net, pickup code, **quantities per district**, deliveries. |
| `POST orders/{id}/confirm` → `start-preparing` → `ready` | Strict order; customers move to Preparing / ReadyForDelivery; on Ready, verified available drivers in the store's city get a delivery-request notification. |
| `GET earnings` · `PUT bank-account {bankName, iban}` · `POST payouts {amount}` | Net money is withdrawable once **all** deliveries of an aggregated order are delivered; before that it's pending settlement. IBAN `SA` + 22 digits; min payout 100 SAR; payouts are serialized per merchant. |

## Driver

All under `/api/driver`, `Driver` role; everything except `home`/`earnings` needs an admin-verified driver.

| Endpoint | |
|---|---|
| `GET home` | Verified/available flags, today's earnings · deliveries · distance, open requests count, active delivery, rating, work city, vehicle. |
| `PATCH availability {available}` | Online / offline. |
| `GET requests` | Unclaimed deliveries of **Ready** aggregated orders in the driver's city (offline → empty). Customer identity hidden. |
| `POST deliveries/{id}/accept` | Atomic claim (conditional UPDATE) — two drivers can't take the same delivery; max 10 active. |
| `POST deliveries/{id}/release` | Give it back before pickup. |
| `POST deliveries/{id}/pickup {pickupCode}` | Code shown in the merchant app. When every delivery of the aggregated order is picked up → merchant order `Completed`. |
| `POST deliveries/{id}/start` | Out for delivery; customer notified with driver name + delivery code. |
| `POST deliveries/{id}/deliver {deliveryCode, proofImageUrl?}` | Code from the customer's order screen → order `Delivered`. |
| `POST deliveries/{id}/fail {reason}` | Customer + merchant notified; order waits for support to reschedule (no automatic refund). |
| `GET deliveries?scope=active\|history` · `GET deliveries/{id}` · `GET earnings?period=week\|month` | Full address/phones only for the driver's own deliveries. |

**Hand-over codes**: merchant → driver uses the aggregated order's `pickupCode`; driver → customer uses each delivery's
`deliveryCode` (visible only to that customer). Merchant earnings become withdrawable when all deliveries are delivered.

## Admin

All under `/api/admin`, `Admin` role. Sign in with `userType: 4` (only existing admin numbers).

| Endpoint | |
|---|---|
| `GET dashboard` | Counts (customers, merchants/drivers verified · pending, drivers online, suspended users, active stores/campaigns, orders today, deliveries in progress / failed, payout requests), 30-day GMV and MIGA commission, last 14 days (GMV + orders), top 5 stores. |
| `GET verifications?type=merchant\|driver\|all&status=pending\|rejected\|verified` | Review queue with the submitted data (business + first store, or ID + city + vehicle). Pending = oldest first. |
| `POST {merchants\|drivers}/{userId}/verify` | Verify (merchant stores go live); the user is notified. |
| `POST {merchants\|drivers}/{userId}/reject {reason}` | Reject with a reason the user sees (`verificationStatus: "rejected"`, `rejectionReason`); re-registering updates the same profile/store and returns it to the queue. |
| `GET users?type=customer\|merchant\|driver&q=&status=all\|active\|suspended\|pending&page=` | Search by name, phone (05… or +966…) or business name; per-role summary (orders/spend, stores, city/vehicle/deliveries). |
| `GET users/{id}` | Details + stores (merchant) + last 10 orders / aggregated orders / deliveries. |
| `PATCH users/{id}/active {active, reason}` | Suspend (reason required) or reactivate. Suspension revokes refresh tokens and is enforced on every request (the JWT handler checks `IsActive`), takes drivers offline and hides merchant stores; admins can't suspend themselves or other admins. |
| `GET campaigns?status=active\|completed\|ended\|draft\|all&q=` · `POST campaigns/{id}/cancel {reason}` | All campaigns with progress; cancelling refunds every paid customer and notifies the merchant with the reason. |
| `GET orders?status=active\|delivered\|closed\|all&q=` · `GET merchant-orders?status=open\|completed\|all&q=` | Customer orders (payment + delivery status) and aggregated orders (deliveries done / total, commission). |
| `GET deliveries?status=failed\|in_progress\|waiting\|delivered\|all&q=` | Driver, customer, store, district, failure reason. |
| `POST deliveries/{id}/retry {note?}` | Failed → back to the same driver as *picked up* (they still hold the goods) to try again; driver and customer notified. |
| `POST deliveries/{id}/refund {reason}` | Failed → cancelled and the customer refunded. The merchant's order then settles without that amount (and without its 5% commission). |
| `GET payouts?status=requested\|paid\|rejected\|all` · `POST payouts/{id}/paid {reference}` · `POST payouts/{id}/reject {reason}` | Merchant withdrawals (full IBAN for the transfer). Paid stores the bank reference; rejected returns the amount to the merchant's available balance. Both notify the merchant. |

