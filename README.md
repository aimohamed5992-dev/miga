# MIGA — منصة الشراء الجماعي بالجملة

Wholesale group-buying: customers join campaigns and pay; when a campaign reaches its target the merchant receives one
aggregated order, prepares it, and drivers deliver each customer's share.

| Part | Folder | Stack |
|---|---|---|
| API | [`backend/`](backend/README.md) | ASP.NET Core (.NET 10) · EF Core 9 · Pomelo · MySQL/MariaDB (XAMPP) |
| Apps | [`mobile/`](mobile/README.md) | Flutter — customer, merchant and driver apps on one design system |
| Admin | [`admin-web/`](admin-web/README.md) | React 19 · TypeScript · Vite · Tailwind v4 — operations dashboard (RTL) |
| Spec | `Miga_Project.pdf` | |
| Image prompts | `docs/IMAGE_PROMPTS.md` (apps) · `docs/ADMIN_IMAGE_PROMPTS.md` (dashboard) | |

## Quick start

1. Start MySQL from XAMPP (root, empty password).
2. `cd backend && dotnet run --project src/Miga.Api --launch-profile http` — migrates and seeds demo data in Development.
3. `cd mobile/apps/miga_merchant && flutter run --dart-define=MIGA_DEV_PHONE=0511111111` (or `miga_customer` /
   `miga_driver` with `0559990001` / `0522222222`).
4. Admin dashboard: `cd admin-web && npm install && npm run dev` → http://localhost:5173 (dev admin `0500000000`; the code is shown on screen).
   The older Flutter Web admin in `mobile/apps/miga_admin` is superseded by `admin-web`.

Tests: `cd backend && dotnet test` · `flutter test` in each package/app (see the READMEs).
