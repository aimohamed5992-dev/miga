# MIGA Admin (React)

Operations dashboard for MIGA: platform numbers, merchant/driver verification, account management, campaigns,
orders, deliveries, the live delivery map, merchant payouts, home banners and platform settings. Arabic, right-to-left,
in the logo colours.

**Stack:** React 19 · TypeScript · Vite · Tailwind CSS v4 · TanStack Query · React Router · Leaflet (map) · lucide icons.

## Run

```bash
# API first: cd ../backend && dotnet run --project src/Miga.Api --launch-profile http
npm install
npm run dev          # http://localhost:5173 — Vite proxies /api and /uploads to http://localhost:5296
```

Sign in with an admin phone (dev: `0500000000`). In Development the API returns the code and the login screen shows it.

| Command | |
|---|---|
| `npm run build` | type-check + production build to `dist/` |
| `npm run lint` | oxlint |
| `npm run preview` | serve the build |

## Configuration (`.env`)

| Variable | Default | |
|---|---|---|
| `VITE_API_URL` | *(same origin)* | API base URL when the dashboard isn't served behind the same host as the API |
| `MIGA_API_URL` | `http://localhost:5296` | dev-server proxy target (shell env, not `VITE_`) |
| `VITE_MAP_TILES_URL` | OpenStreetMap tiles | map tile template, e.g. a MapTiler/Mapbox URL with your key — use a keyed provider in production |
| `VITE_MAP_TILES_ATTRIBUTION` | OpenStreetMap | attribution HTML for the tiles above |

The API must allow the dashboard's origin in production (`Cors:Origins` in the API settings).

## Structure

```
src/
  lib/          api client (tokens, refresh, Arabic errors), queries & actions, types + Arabic labels, formatting
  auth/         session restore / sign-in state
  layout/       AppShell (sidebar, top bar), nav.ts (sections + counters)
  components/   ui/ primitives (Button, Field, Modal, Drawer, DataTable, Tabs…), AccountActions, ReasonDialog,
                UserPanel, BannerEditor, charts/RevenueChart
  pages/        one file per section
public/
  fonts/        Tajawal (bundled)
  images/       dashboard artwork — see docs/ADMIN_IMAGE_PROMPTS.md (placeholders show until files exist)
```

List filters live in the URL (`?status=…&q=…&page=…`), so reloads and shared links keep the view. Every admin action
asks for confirmation; actions the affected user sees (reject, suspend, cancel, refund) require a written reason.

## Live map

`GET /api/admin/map` returns open deliveries, their stores and drivers on duty. Driver positions come from the driver
app (`POST /api/driver/location` every 30 s while online). Customers and stores have no saved GPS yet, so they are
placed at the district / city centre and drawn with a dashed outline ("approximate").
