import clsx from 'clsx'
import L, { type LatLngExpression } from 'leaflet'
import 'leaflet/dist/leaflet.css'
import { AlertTriangle, Bike, CircleDot, MapPin, Package, Phone, Store, Truck } from 'lucide-react'
import { useEffect, useMemo, useRef, useState, type ReactNode } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { MapContainer, Marker, Polyline, Popup, TileLayer, useMap as useLeafletMap } from 'react-leaflet'
import { useSearchParams } from 'react-router-dom'
import { Badge } from '../components/ui/Badge'
import { Illustration } from '../components/ui/Illustration'
import { Skeleton } from '../components/ui/ListControls'
import { fmt } from '../lib/format'
import { useMap } from '../lib/queries'
import { deliveryStatus, label, vehicleLabel, type AdminMap, type MapDelivery, type MapDriver, type MapPoint, type MapStore } from '../lib/types'

/**
 * Base map. OpenStreetMap's own tiles are fine for an internal tool with light traffic; for production set
 * VITE_MAP_TILES_URL (+ VITE_MAP_TILES_ATTRIBUTION) to a keyed provider such as MapTiler or Mapbox.
 */
const TILES = {
  url: import.meta.env.VITE_MAP_TILES_URL || 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  attribution:
    import.meta.env.VITE_MAP_TILES_ATTRIBUTION || '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
}

// ---------------------------------------------------------------- markers

type Stage = 'waiting' | 'moving' | 'failed'
const stageOf = (s: number): Stage => (s === 7 ? 'failed' : s >= 3 && s <= 5 ? 'moving' : 'waiting')
const stageColor: Record<Stage, string> = { waiting: '#a1a1ab', moving: '#c4011a', failed: '#5c000c' }

const svg = (node: ReactNode) => renderToStaticMarkup(<>{node}</>)

function pinIcon(stage: Stage, approximate: boolean, selected: boolean) {
  const size = selected ? 46 : 36
  const color = stageColor[stage]
  return L.divIcon({
    className: '',
    iconSize: [size, size],
    iconAnchor: [size / 2, size],
    popupAnchor: [0, -size + 6],
    html: svg(
      <div style={{ width: size, height: size, position: 'relative', filter: 'drop-shadow(0 6px 8px rgb(0 0 0 / .25))' }}>
        <svg viewBox="0 0 24 24" width={size} height={size}>
          <path
            d="M12 23s-8-7.6-8-13.2A8 8 0 0 1 20 9.8C20 15.4 12 23 12 23Z"
            fill={color}
            stroke="#fff"
            strokeWidth={1.6}
            strokeDasharray={approximate ? '2.2 1.6' : undefined}
          />
          {stage === 'failed' ? (
            <text x="12" y="13.6" textAnchor="middle" fontSize="9" fontWeight="800" fill="#fff">
              !
            </text>
          ) : (
            <circle cx="12" cy="10" r="3.2" fill="#fff" />
          )}
        </svg>
      </div>,
    ),
  })
}

function storeIcon(active: number, dim: boolean) {
  return L.divIcon({
    className: '',
    iconSize: [34, 34],
    iconAnchor: [17, 17],
    popupAnchor: [0, -16],
    html: svg(
      <div
        style={{ opacity: dim ? 0.55 : 1 }}
        className="relative flex size-[34px] items-center justify-center rounded-[11px] border-2 border-white bg-brand-800 text-white shadow-[0_6px_14px_rgb(0_0_0/.28)]"
      >
        <Store size={17} />
        {active > 0 && (
          <span className="absolute -end-2 -top-2 flex h-5 min-w-5 items-center justify-center rounded-full border-2 border-white bg-brand-600 px-1 text-[10px] font-extrabold">
            {active}
          </span>
        )}
      </div>,
    ),
  })
}

function driverIcon(d: MapDriver, selected: boolean) {
  const live = !d.position.approximate
  const ring = d.isAvailable ? '#c4011a' : '#a1a1ab'
  const size = selected ? 44 : 36
  return L.divIcon({
    className: '',
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    popupAnchor: [0, -size / 2],
    html: svg(
      <div className="relative" style={{ width: size, height: size }}>
        {live && d.isAvailable && <span className="absolute inset-0 animate-ping rounded-full" style={{ background: ring, opacity: 0.35 }} />}
        <div
          className="relative flex size-full items-center justify-center rounded-full bg-white shadow-[0_6px_14px_rgb(0_0_0/.25)]"
          style={{ border: `3px ${live ? 'solid' : 'dashed'} ${ring}` }}
        >
          <Bike size={size * 0.48} color="#16161a" />
        </div>
        {d.activeDeliveries > 0 && (
          <span className="absolute -end-1.5 -top-1.5 flex h-5 min-w-5 items-center justify-center rounded-full border-2 border-white bg-brand-600 px-1 text-[10px] font-extrabold text-white">
            {d.activeDeliveries}
          </span>
        )}
      </div>,
    ),
  })
}

const ll = (p: MapPoint): LatLngExpression => [p.lat, p.lng]

// ---------------------------------------------------------------- map helpers

/** Fits the view to everything when the city changes / data first arrives, and to the route when a delivery is selected. */
function ViewController({
  data,
  cityKey,
  focusKey,
  focus,
}: {
  data?: AdminMap
  cityKey: string
  /** Changes when the admin selects another delivery; the view moves only then, not on every live refresh. */
  focusKey: string | null
  focus: LatLngExpression[] | null
}) {
  const map = useLeafletMap()
  const fitted = useRef<string | null>(null)
  const latestFocus = useRef(focus)
  useEffect(() => {
    latestFocus.current = focus
  })

  useEffect(() => {
    if (!data || fitted.current === cityKey) return
    const pts = [...data.deliveries.map((d) => d.destination), ...data.drivers.map((d) => d.position), ...data.stores.map((s) => s.position)]
    if (pts.length === 0) {
      const c = data.cities[0]
      if (c) map.setView([c.lat, c.lng], 11)
      else map.setView([23.9, 45.1], 5) // Saudi Arabia
    } else {
      map.fitBounds(L.latLngBounds(pts.map((p) => [p.lat, p.lng] as [number, number])), { padding: [60, 60], maxZoom: 13 })
    }
    fitted.current = cityKey
  }, [data, cityKey, map])

  useEffect(() => {
    const f = latestFocus.current
    if (focusKey && f && f.length) map.flyToBounds(L.latLngBounds(f), { padding: [90, 90], maxZoom: 14, duration: 0.8 })
  }, [focusKey, map])

  return null
}

function PopupBody({ title, sub, children }: { title: string; sub?: ReactNode; children?: ReactNode }) {
  return (
    <div dir="rtl" className="min-w-52 font-sans">
      <p className="text-[15px] font-extrabold text-ink">{title}</p>
      {sub && <p className="mt-0.5 text-xs text-muted">{sub}</p>}
      {children && <div className="mt-2 space-y-1 text-[13px] text-ink-3">{children}</div>}
    </div>
  )
}

const Approx = ({ what }: { what: string }) => <p className="text-xs text-warn">📍 موقع تقريبي ({what})</p>

// ---------------------------------------------------------------- side panel

type Filter = 'all' | Stage

function DeliveryItem({ d, selected, onSelect }: { d: MapDelivery; selected: boolean; onSelect: () => void }) {
  const [t, tone] = label(deliveryStatus, d.status)
  return (
    <button
      onClick={onSelect}
      className={clsx(
        'w-full rounded-2xl border p-3.5 text-start transition-all',
        selected ? 'border-brand-500 bg-brand-50/60 shadow-card' : 'border-line bg-white hover:border-brand-200',
      )}
    >
      <div className="flex items-center justify-between gap-2">
        <span className="num text-sm font-extrabold" dir="ltr">
          {d.number}
        </span>
        <Badge tone={tone} dot>
          {t}
        </Badge>
      </div>
      <p className="mt-2 truncate text-sm font-bold">
        {d.customerName} <span className="font-normal text-muted">· {d.district}</span>
      </p>
      <p className="mt-1 flex items-center gap-1.5 truncate text-xs text-muted">
        <Store className="size-3.5 shrink-0" /> {d.storeName}
        <span className="text-faint">←</span>
        {d.driverName ? (
          <>
            <Bike className="size-3.5 shrink-0" /> {d.driverName}
          </>
        ) : (
          <span className="text-warn">بلا مندوب</span>
        )}
      </p>
      {d.failureReason && (
        <p className="mt-1.5 flex items-center gap-1 truncate text-xs text-danger">
          <AlertTriangle className="size-3 shrink-0" /> {d.failureReason}
        </p>
      )}
    </button>
  )
}

function Stat({ icon, value, text, tone }: { icon: ReactNode; value: number; text: string; tone: string }) {
  return (
    <div className="rounded-2xl bg-white p-3 shadow-card">
      <div className="flex items-center gap-2">
        <span className={clsx('flex size-7 items-center justify-center rounded-lg', tone)}>{icon}</span>
        <span className="num text-xl font-extrabold">{fmt.int(value)}</span>
      </div>
      <p className="mt-1 text-xs text-muted">{text}</p>
    </div>
  )
}

// ---------------------------------------------------------------- page

export function MapPage() {
  const [params, setParams] = useSearchParams()
  const cityId = params.get('city')
  const selectedId = params.get('delivery')
  const [filter, setFilter] = useState<Filter>('all')
  const { data, isLoading, dataUpdatedAt } = useMap(cityId)

  const setParam = (k: string, v: string | null) =>
    setParams(
      (p) => {
        if (v) p.set(k, v)
        else p.delete(k)
        return p
      },
      { replace: true },
    )

  const deliveries = useMemo(() => data?.deliveries ?? [], [data])
  const storeById = useMemo(() => new Map((data?.stores ?? []).map((s) => [s.id, s])), [data])
  const driverById = useMemo(() => new Map((data?.drivers ?? []).map((d) => [d.userId, d])), [data])
  const selected = deliveries.find((d) => d.id === selectedId) ?? null
  const counts = {
    waiting: deliveries.filter((d) => stageOf(d.status) === 'waiting').length,
    moving: deliveries.filter((d) => stageOf(d.status) === 'moving').length,
    failed: deliveries.filter((d) => stageOf(d.status) === 'failed').length,
  }
  const visible = filter === 'all' ? deliveries : deliveries.filter((d) => stageOf(d.status) === filter)
  const online = data?.drivers.filter((d) => d.isAvailable).length ?? 0

  // Route of the selected delivery: store → driver (while carrying it) → customer.
  const route: LatLngExpression[] | null = selected
    ? ([
        storeById.get(selected.storeId)?.position,
        stageOf(selected.status) === 'moving' && selected.driverUserId ? driverById.get(selected.driverUserId)?.position : undefined,
        selected.destination,
      ].filter(Boolean) as MapPoint[]).map(ll)
    : null

  return (
    <div className="-mx-4 -my-6 flex h-[calc(100dvh-72px)] flex-col sm:-mx-8 sm:-my-8 lg:flex-row">
      {/* Side panel */}
      <aside className="order-2 flex max-h-[45%] w-full shrink-0 flex-col border-line bg-canvas lg:order-none lg:max-h-none lg:w-[380px] lg:border-e">
        <div className="space-y-4 border-b border-line p-4">
          <div className="flex gap-2 overflow-x-auto pb-1">
            <button
              onClick={() => setParams({}, { replace: true })}
              className={clsx(
                'shrink-0 rounded-full px-3.5 py-1.5 text-sm font-bold',
                !cityId ? 'bg-brand-600 text-white' : 'bg-white text-ink-3 shadow-card hover:text-brand-700',
              )}
            >
              كل المدن
            </button>
            {data?.cities.map((c) => (
              <button
                key={c.id}
                onClick={() => setParams({ city: c.id }, { replace: true })}
                className={clsx(
                  'flex shrink-0 items-center gap-1.5 rounded-full px-3.5 py-1.5 text-sm font-bold',
                  cityId === c.id ? 'bg-brand-600 text-white' : 'bg-white text-ink-3 shadow-card hover:text-brand-700',
                )}
              >
                {c.name}
                {c.deliveries > 0 && <span className="num rounded-full bg-brand-600 px-1.5 text-[11px] text-white">{c.deliveries}</span>}
              </button>
            ))}
          </div>
          <div className="grid grid-cols-4 gap-2">
            <Stat icon={<Package className="size-4" />} value={counts.waiting} text="بانتظار" tone="bg-black/5 text-ink-3" />
            <Stat icon={<Truck className="size-4" />} value={counts.moving} text="مع المندوب" tone="bg-brand-50 text-brand-600" />
            <Stat icon={<AlertTriangle className="size-4" />} value={counts.failed} text="متعثرة" tone="bg-brand-800 text-white" />
            <Stat icon={<Bike className="size-4" />} value={online} text="متصلون" tone="bg-brand-600 text-white" />
          </div>
        </div>

        <div className="flex items-center gap-1 border-b border-line px-4 py-2.5">
          {(
            [
              ['all', 'الكل'],
              ['waiting', 'بانتظار'],
              ['moving', 'مع المندوب'],
              ['failed', 'متعثرة'],
            ] as const
          ).map(([v, t]) => (
            <button
              key={v}
              onClick={() => setFilter(v)}
              className={clsx('rounded-lg px-3 py-1.5 text-xs font-bold', filter === v ? 'bg-white text-ink shadow-card' : 'text-muted hover:text-ink')}
            >
              {t}
            </button>
          ))}
        </div>

        <div className="flex-1 space-y-2.5 overflow-y-auto p-4">
          {isLoading ? (
            [0, 1, 2].map((i) => <Skeleton key={i} className="h-24" />)
          ) : visible.length === 0 ? (
            <div className="flex flex-col items-center py-8 text-center">
              <Illustration name="admin_map_empty" className="size-32" />
              <p className="mt-3 font-bold">لا توجد توصيلات مفتوحة</p>
              <p className="mt-1 text-xs text-muted">ستظهر هنا فور جاهزية طلبات التجار.</p>
            </div>
          ) : (
            visible.map((d) => <DeliveryItem key={d.id} d={d} selected={d.id === selectedId} onSelect={() => setParam('delivery', d.id === selectedId ? null : d.id)} />)
          )}
        </div>
      </aside>

      {/* Map */}
      <div className="relative min-h-0 flex-1" dir="ltr">
        <MapContainer center={[23.9, 45.1]} zoom={5} className="size-full" zoomControl={false} attributionControl>
          <TileLayer url={TILES.url} attribution={TILES.attribution} maxZoom={19} />
          <ViewController data={data} cityKey={cityId ?? 'all'} focusKey={selected?.id ?? null} focus={route} />

          {route && route.length > 1 && (
            <Polyline positions={route} pathOptions={{ color: '#c4011a', weight: 4, opacity: 0.85, dashArray: '8 10', lineCap: 'round' }} />
          )}

          {data?.stores.map((s: MapStore) => (
            <Marker key={s.id} position={ll(s.position)} icon={storeIcon(s.activeDeliveries, !!selected && selected.storeId !== s.id)}>
              <Popup>
                <PopupBody title={s.name} sub={s.city ?? undefined}>
                  {s.pickupAddress && <p>📦 {s.pickupAddress}</p>}
                  <p>
                    <b className="num">{s.activeDeliveries}</b> توصيلة مفتوحة
                  </p>
                  {s.position.approximate && <Approx what="داخل المدينة" />}
                </PopupBody>
              </Popup>
            </Marker>
          ))}

          {data?.drivers.map((d) => (
            <Marker key={d.userId} position={ll(d.position)} icon={driverIcon(d, selected?.driverUserId === d.userId)} zIndexOffset={500}>
              <Popup>
                <PopupBody title={d.name} sub={[d.city, d.vehicleType && (vehicleLabel[d.vehicleType] ?? d.vehicleType)].filter(Boolean).join(' · ')}>
                  <p className="flex items-center gap-1.5">
                    <CircleDot className={clsx('size-3.5', d.isAvailable ? 'text-brand-600' : 'text-faint')} /> {d.isAvailable ? 'متصل' : 'غير متصل'} ·{' '}
                    <b className="num">{d.activeDeliveries}</b> توصيلة معه
                  </p>
                  <a href={`tel:${d.phone}`} className="num flex items-center gap-1.5 text-brand-600" dir="ltr">
                    <Phone className="size-3.5" /> {fmt.phone(d.phone)}
                  </a>
                  {d.locationAt ? <p className="text-xs text-muted">آخر موقع {fmt.ago(d.locationAt)}</p> : <Approx what="لم يرسل التطبيق موقعه بعد" />}
                </PopupBody>
              </Popup>
            </Marker>
          ))}

          {deliveries.map((d) => (
            <Marker
              key={d.id}
              position={ll(d.destination)}
              icon={pinIcon(stageOf(d.status), d.destination.approximate, d.id === selectedId)}
              zIndexOffset={d.id === selectedId ? 1000 : 0}
              opacity={selected && d.id !== selectedId ? 0.45 : 1}
              eventHandlers={{ click: () => setParam('delivery', d.id) }}
            >
              <Popup>
                <PopupBody title={d.customerName} sub={`${d.district}، ${d.city}`}>
                  <p className="num" dir="ltr">
                    {d.number}
                  </p>
                  <p>
                    {d.productName} <span className="num">×{d.quantity}</span>
                  </p>
                  <p>{label(deliveryStatus, d.status)[0]}</p>
                  {d.destination.approximate && <Approx what="مركز الحي" />}
                </PopupBody>
              </Popup>
            </Marker>
          ))}
        </MapContainer>

        {/* Legend + live indicator */}
        <div dir="rtl" className="pointer-events-none absolute inset-x-3 bottom-3 z-[500] flex flex-wrap items-end justify-between gap-2">
          <div className="pointer-events-auto rounded-2xl bg-white/95 p-2.5 text-[11px] shadow-pop backdrop-blur sm:p-3 sm:text-xs">
            <div className="flex flex-wrap items-center gap-x-4 gap-y-1.5">
              <span className="flex items-center gap-1.5">
                <span className="size-3 rounded-[4px] bg-brand-800" /> متجر
              </span>
              <span className="flex items-center gap-1.5">
                <span className="size-3 rounded-full border-2 border-brand-600 bg-white" /> مندوب متصل
              </span>
              <span className="flex items-center gap-1.5">
                <MapPin className="size-3.5" style={{ color: stageColor.waiting }} /> بانتظار مندوب
              </span>
              <span className="flex items-center gap-1.5">
                <MapPin className="size-3.5" style={{ color: stageColor.moving }} /> مع المندوب
              </span>
              <span className="flex items-center gap-1.5">
                <MapPin className="size-3.5" style={{ color: stageColor.failed }} /> متعثرة
              </span>
            </div>
            <p className="mt-1.5 hidden text-muted sm:block">الحدود المتقطعة = موقع تقريبي (مركز الحي أو المدينة) حتى يتوفر الموقع الدقيق.</p>
          </div>
          {dataUpdatedAt > 0 && (
            <span className="pointer-events-auto flex items-center gap-2 rounded-full bg-brand-600 px-3 py-1.5 text-xs font-bold text-white shadow-pop">
              <span className="relative flex size-2">
                <span className="absolute inset-0 animate-ping rounded-full bg-white" />
                <span className="relative size-2 rounded-full bg-white" />
              </span>
              مباشر · يتحدّث كل 15 ث
            </span>
          )}
        </div>
      </div>
    </div>
  )
}
