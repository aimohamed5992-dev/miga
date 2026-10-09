# MIGA Admin (React) — Image Prompts

> Put every finished image in `Miga/design_assets/admin/` with the **exact file name** shown. I will move them into
> `admin-web/public/images/`. Until an image exists the dashboard shows a branded placeholder, so nothing breaks.
>
> Brand: **logo red only** — crimson `#C4011A` and its darker shade `#8E0013`, with white and soft grey `#F5F5F7`.
> No other accent colours (no blue, green or gold) in any image.

---

## 0) Shared style blocks (paste at the END of each prompt)

**[STYLE-ADMIN-3D]** — illustrations (login, empty states, errors)
```
premium 3D clay-style illustration, soft rounded geometry, glossy matte materials, brand palette strictly crimson red #C4011A and deep red #8E0013 with white and cool light grey only, no other colours, soft studio lighting from top left, gentle ambient occlusion, subtle soft shadow under objects, clean minimal composition, isometric 3/4 view, plenty of empty space, transparent background, no text, no letters, no numbers, no logos, no watermark, high detail, 4k
```

**[STYLE-ADMIN-WIDE]** — wide header artwork
```
premium 3D clay-style scene, wide panoramic composition, main subject on the LEFT third, the RIGHT 60% kept clean with a smooth soft gradient from light grey to white for overlaying Arabic text, brand palette crimson red #C4011A, deep red #8E0013, white and cool grey, soft studio lighting, no text, no letters, no numbers, no logos, no watermark, 4k
```

> People (if any): Gulf/Saudi context, modest clothing (man in white thobe and red-white shemagh, woman in black abaya with hijab), friendly stylized faces (not realistic).

---

## 1) Login

No images needed — the login page is drawn in code (logo-red background, logo watermark, centered card).

## 2) Dashboard (`admin_dash_*`)

| File | Size | Prompt |
|---|---|---|
| `admin_dash_welcome.png` | 1800×480, PNG | A row of 3D objects on the left: a rising bar chart with a red arrow going up, a coin stack, a shopping bag and a small delivery van, morning soft light, celebratory but professional mood, [STYLE-ADMIN-WIDE] |
| `admin_dash_all_clear.png` | 800×800, transparent PNG | A calm checklist clipboard with all items ticked in red, a cup of Arabic coffee (dallah and finjan) beside it, small sparkles, relaxed "everything is under control" feeling, [STYLE-ADMIN-3D] |

## 3) Map (`admin_map_*`)

| File | Size | Prompt |
|---|---|---|
| `admin_map_empty.png` | 800×800, transparent PNG | A folded paper city map with a single red map pin resting on it, a small idle red delivery van parked beside it, quiet calm mood, [STYLE-ADMIN-3D] |

## 4) Empty states (`admin_empty_*`, 800×800, transparent PNG)

| File | Prompt |
|---|---|
| `admin_empty_verifications.png` | A white shield with a large red checkmark in front of two stacked ID cards and a stamped document, "all reviewed" feeling, [STYLE-ADMIN-3D] |
| `admin_empty_deliveries.png` | Three cardboard parcels neatly stacked and tied with red ribbons, a red checkmark badge floating above, smooth road ending at a door, [STYLE-ADMIN-3D] |
| `admin_empty_payouts.png` | A classic bank building icon with a closed red wallet and a calm stack of coins in front, a small check badge, [STYLE-ADMIN-3D] |
| `admin_empty_search.png` | A large magnifying glass with a red handle over an empty open box, [STYLE-ADMIN-3D] |
| `admin_empty_banners.png` | An empty picture frame / billboard with a red image icon placeholder and a small plus badge, [STYLE-ADMIN-3D] |
| `admin_empty_list.png` | An empty clipboard with blank lines and a red pen lying across it, [STYLE-ADMIN-3D] |

## 5) Errors (`admin_error_*`, 800×800, transparent PNG)

| File | Prompt |
|---|---|
| `admin_error_offline.png` | A red Wi-Fi symbol with a small unplugged cable and a cloud with a slash, [STYLE-ADMIN-3D] |
| `admin_error_forbidden.png` | A red padlock on a closed steel door with a small shield badge, [STYLE-ADMIN-3D] |

---

**Total: 11 images.** Priority if time is short: `admin_dash_welcome`, `admin_dash_all_clear`, `admin_map_empty`, `admin_empty_verifications`.
