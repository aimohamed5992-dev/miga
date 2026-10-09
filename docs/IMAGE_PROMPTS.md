# MIGA — Image Prompts (Step 1)

> Put every finished image in `Miga/design_assets/` with the **exact file name** shown. I will move them into the Flutter projects.
> Brand red: `#C4011A` · White `#FFFFFF` · Soft grey `#F5F5F7` · Dark `#1A1A1A`

---

## 0) Shared style blocks (paste at the END of each prompt)

**[STYLE-3D]** (for all illustrations: onboarding / auth / empty states / success)
```
3D clay-style illustration, soft rounded shapes, glossy matte materials, brand color palette crimson red #C4011A with white and light warm grey accents, soft studio lighting, subtle soft shadow under objects, clean minimal composition, centered subject, plenty of empty space around, transparent background, no text, no letters, no logos, no watermark, high detail, 4k
```

**[STYLE-PHOTO]** (for product photos)
```
professional e-commerce product photography, single product centered, pure white background #FFFFFF, soft diffused studio lighting, subtle natural shadow, sharp focus, high resolution, no text, no logo, no watermark, no hands, square 1:1
```

**[STYLE-BANNER]** (for home banners / store covers)
```
modern commercial advertising photo, wide composition, main subject placed on the RIGHT third, the LEFT 60% kept clean and softly blurred for overlaying Arabic text, warm premium lighting, subtle crimson red #C4011A accents, no text, no letters, no logo, no watermark
```

> People in illustrations: Gulf/Saudi context, modest clothing (men in white thobe, women in black abaya with hijab), friendly, stylized (not realistic faces).

---

## 1) Customer app (`customer_`)

### Onboarding (1080×1080, transparent PNG)
| File | Prompt |
|---|---|
| `customer_onb_1.png` | A group of diverse stylized Saudi people (man in white thobe, woman in abaya, young man in casual wear) joyfully holding one big shopping bag together, small floating price tags with a downward arrow showing price drop, [STYLE-3D] |
| `customer_onb_2.png` | A large circular progress ring almost full (about 75%) with small 3D people avatars joining around it, a big gift box opening in the center with sparkles, celebration feeling of a goal being reached, [STYLE-3D] |
| `customer_onb_3.png` | A cute red delivery van driving out of a phone screen toward a modern Saudi villa door, a cardboard parcel with a checkmark floating above, map pin icon, [STYLE-3D] |

### Auth & states (800×800, transparent PNG)
| File | Prompt |
|---|---|
| `customer_auth.png` | A modern smartphone standing upright with a shield and a key icon and a chat bubble showing a hidden code (dots), secure login concept, [STYLE-3D] |
| `customer_location.png` | A 3D map folded with a big red location pin and a small house next to it, choosing delivery address concept, [STYLE-3D] |
| `customer_payment_success.png` | A credit card and a phone with a big glossy red circle checkmark, confetti pieces around, payment success, [STYLE-3D] |
| `customer_campaign_complete.png` | A trophy cup made of shopping bags with a 100% progress badge and confetti, group goal achieved, [STYLE-3D] |

### Home banners (1600×700, JPG)
| File | Prompt |
|---|---|
| `banner_1.jpg` | Stack of wholesale cardboard boxes and shopping bags with a few group-purchase people silhouettes in a bright modern warehouse, [STYLE-BANNER] |
| `banner_2.jpg` | Latest smartphones, headphones and smartwatch arranged on a sleek red-and-white podium, [STYLE-BANNER] |
| `banner_3.jpg` | Premium grocery: rice sacks, dates, olive oil bottles, coffee beans arranged on a wooden table, [STYLE-BANNER] |

### Store categories (512×512, transparent PNG, same angle & size for all 6)
| File | Prompt |
|---|---|
| `cat_restaurants.png` | A burger with fries and a drink cup, [STYLE-3D] |
| `cat_electronics.png` | A smartphone and wireless headphones, [STYLE-3D] |
| `cat_fashion.png` | A folded shirt, a sneaker and a handbag, [STYLE-3D] |
| `cat_grocery.png` | A paper grocery bag with vegetables, bread and a milk bottle, [STYLE-3D] |
| `cat_beauty.png` | A perfume bottle, a lipstick and a cream jar, [STYLE-3D] |
| `cat_home.png` | A modern armchair with a small lamp and a plant, [STYLE-3D] |

### Products (1024×1024, JPG) — used in demo campaigns
| File | Prompt |
|---|---|
| `p_phone.jpg` | Modern flagship smartphone, front and back view side by side, titanium finish, [STYLE-PHOTO] |
| `p_headphones.jpg` | Premium over-ear wireless headphones, matte white, [STYLE-PHOTO] |
| `p_watch.jpg` | Modern smartwatch with black sport band, [STYLE-PHOTO] |
| `p_laptop.jpg` | Thin silver laptop half-open showing a blank dark screen, [STYLE-PHOTO] |
| `p_perfume.jpg` | Luxury Arabic oud perfume bottle, dark glass with gold cap, [STYLE-PHOTO] |
| `p_sneakers.jpg` | White running sneakers pair, [STYLE-PHOTO] |
| `p_rice.jpg` | 10kg basmati rice sack with blank label (no text), [STYLE-PHOTO] |
| `p_dates.jpg` | Premium Saudi dates in an elegant open box, [STYLE-PHOTO] |
| `p_coffee.jpg` | Arabic coffee beans pack (blank package) with a dallah coffee pot, [STYLE-PHOTO] |
| `p_oil.jpg` | Two bottles of extra virgin olive oil with blank labels, [STYLE-PHOTO] |
| `p_skincare.jpg` | Skincare set of three white bottles and a jar with blank labels, [STYLE-PHOTO] |
| `p_cookware.jpg` | Non-stick cookware set of pots and pans, black with red handles, [STYLE-PHOTO] |

### Stores (logos 512×512 PNG · covers 1600×900 JPG)
| File | Prompt |
|---|---|
| `store_cover_electronics.jpg` | Modern electronics store interior with bright shelves of gadgets, [STYLE-BANNER] |
| `store_cover_grocery.jpg` | Clean wholesale grocery market with organized shelves, [STYLE-BANNER] |
| `store_cover_fashion.jpg` | Minimal fashion boutique with clothes racks, [STYLE-BANNER] |
| `store_cover_beauty.jpg` | Luxury perfume and beauty shop with glass shelves, [STYLE-BANNER] |
| `store_logo_1.png` … `store_logo_4.png` | Simple flat abstract brand mark, a single geometric symbol in a circle, one solid color (navy / green / gold / purple respectively), white background, vector style, no text |

---

## 2) Merchant app (`merchant_`)

### Onboarding (1080×1080, transparent PNG)
| File | Prompt |
|---|---|
| `merchant_onb_1.png` | A Saudi merchant in white thobe standing next to a large tablet showing a campaign card with a progress bar and a price tag, launching a campaign rocket, [STYLE-3D] |
| `merchant_onb_2.png` | A big stack of cardboard boxes forming one combined order with a clipboard checklist, many small order icons flowing into one large box, [STYLE-3D] |
| `merchant_onb_3.png` | A rising bar chart with gold coins and a riyal-style coin stack, upward arrow, business growth, [STYLE-3D] |

### Auth & states (800×800, transparent PNG)
| File | Prompt |
|---|---|
| `merchant_auth.png` | A small modern storefront with a red awning and a shield checkmark on it, secure business login, [STYLE-3D] |
| `merchant_store_setup.png` | A storefront being built with a paint roller and a logo placeholder board (blank), setting up a shop, [STYLE-3D] |
| `merchant_order_ready.png` | Sealed cardboard boxes on a pallet with a big red checkmark and a delivery driver arriving, ready for pickup, [STYLE-3D] |

---

## 3) Driver app (`driver_`)

### Onboarding (1080×1080, transparent PNG)
| File | Prompt |
|---|---|
| `driver_onb_1.png` | A smartphone showing a notification bell with new delivery requests popping out as small parcel icons, [STYLE-3D] |
| `driver_onb_2.png` | A red delivery van on a curvy road on a 3D city map with route line and pins from store to house, [STYLE-3D] |
| `driver_onb_3.png` | A wallet with coins and banknotes coming out, a calendar and an upward arrow, daily earnings, [STYLE-3D] |

### Auth & states (800×800, transparent PNG)
| File | Prompt |
|---|---|
| `driver_auth.png` | A friendly Saudi delivery driver in red cap and red uniform standing next to a red van holding a parcel, [STYLE-3D] |
| `driver_delivered.png` | A parcel at a house door with a big red checkmark and a signature line, delivered successfully, [STYLE-3D] |
| `map_placeholder.jpg` (1080×1920) | Clean minimal light-grey city street map top view, Riyadh style roads, no labels, no text, flat vector map style, soft colors |

---

## 4) Shared empty states (800×800, transparent PNG)
| File | Prompt |
|---|---|
| `empty_cart.png` | An empty shopping cart with a small cobweb and a floating question mark, [STYLE-3D] |
| `empty_orders.png` | An empty open cardboard box with a magnifying glass, [STYLE-3D] |
| `empty_notifications.png` | A sleeping bell with "zzz" bubbles (no letters, use shapes), [STYLE-3D] |
| `empty_campaigns.png` | An empty megaphone on a podium with a faded progress bar, [STYLE-3D] |
| `no_internet.png` | A broken wifi signal with an unplugged cable, [STYLE-3D] |
| `error_failed.png` | A credit card with a red cross badge and a warning triangle, payment failed / campaign failed, [STYLE-3D] |

---

## Not needed from you
- **Splash screens**: built in code (animated logo on red/white) from `logo.png`.
- **App icons**: generated from `logo.png`.
- **Avatars**: I'll render initials.
- **Fonts**: I'll use Google Font **Tajawal** (Arabic) — no files needed.

**Total: 54 images** (minimum to start: the 9 onboarding images, 6 categories, 3 banners and 8 products).
