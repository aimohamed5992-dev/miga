import clsx from 'clsx'
import { useState } from 'react'
import { fmt } from '../../lib/format'
import type { DashboardDay } from '../../lib/types'

const weekday = new Intl.DateTimeFormat('ar', { weekday: 'long' })

/** Rounds up to 1/2/2.5/5 × 10ⁿ so the grid lines land on readable values. */
function niceMax(v: number) {
  if (v <= 0) return 1000
  const p = 10 ** Math.floor(Math.log10(v))
  return ([1, 2, 2.5, 5, 10].find((m) => m * p >= v) ?? 10) * p
}

const short = (v: number) => (v >= 1000 ? `${fmt.int(Math.round(v / 100) / 10)}k` : fmt.int(v))

/**
 * Daily paid sales (single series → bars, no legend). Hover/focus a day for the exact amount and order count.
 * Time runs left → right like every other number chart, even inside the RTL page.
 */
export function RevenueChart({ days }: { days: DashboardDay[] }) {
  const [hover, setHover] = useState<number | null>(null)
  const max = niceMax(Math.max(...days.map((d) => d.gmv)))
  const ticks = [0, 0.25, 0.5, 0.75, 1].map((f) => f * max)

  return (
    <div dir="ltr" className="flex h-64 gap-3 select-none" onMouseLeave={() => setHover(null)}>
      {/* y axis */}
      <div className="relative w-10 shrink-0">
        <div className="absolute inset-x-0 top-0 bottom-7">
          {ticks.map((t) => (
            <span key={t} className="num absolute end-0 translate-y-1/2 text-[11px] text-faint" style={{ bottom: `${(t / max) * 100}%` }}>
              {short(t)}
            </span>
          ))}
        </div>
      </div>
      <div className="relative flex-1">
        {/* grid */}
        <div className="absolute inset-x-0 top-0 bottom-7">
          {ticks.map((t) => (
            <div key={t} className={clsx('absolute inset-x-0 border-t', t === 0 ? 'border-line' : 'border-dashed border-line/70')} style={{ bottom: `${(t / max) * 100}%` }} />
          ))}
        </div>
        {/* bars */}
        <div className="absolute inset-0 flex">
          {days.map((d, i) => {
            const date = new Date(d.date)
            const h = (d.gmv / max) * 100
            const active = hover === i
            return (
              <div
                key={d.date}
                tabIndex={0}
                aria-label={`${fmt.date(date)}: ${fmt.money(d.gmv)}، ${d.orders} طلب`}
                onMouseEnter={() => setHover(i)}
                onFocus={() => setHover(i)}
                onBlur={() => setHover(null)}
                className="relative flex flex-1 flex-col outline-none"
              >
                <div className={clsx('relative mx-[1px] flex flex-1 items-end justify-center rounded-lg transition-colors', active && 'bg-brand-50/70')}>
                  {d.gmv > 0 && (
                    <div
                      className={clsx('w-[min(60%,28px)] rounded-t-[4px] transition-all duration-500', active ? 'bg-brand-700' : 'bg-brand-600')}
                      style={{ height: `${Math.max(h, 1.5)}%` }}
                    />
                  )}
                  {active && (
                    <div
                      dir="rtl"
                      className={clsx(
                        'pointer-events-none absolute z-10 w-max rounded-xl bg-brand-800 px-3.5 py-2.5 text-white shadow-pop',
                        i < 3 ? 'left-0' : i > days.length - 4 ? 'right-0' : 'left-1/2 -translate-x-1/2',
                      )}
                      style={{ bottom: `calc(${Math.max(h, 0)}% + 8px)` }}
                    >
                      <p className="text-xs text-white/60">
                        {weekday.format(date)} <span className="num">{fmt.date(date)}</span>
                      </p>
                      <p className="num mt-0.5 font-extrabold">{fmt.money(d.gmv)}</p>
                      <p className="num text-xs text-white/70">{fmt.int(d.orders)} طلب مدفوع</p>
                    </div>
                  )}
                </div>
                <span className={clsx('num mt-2 h-5 text-center text-[11px]', active ? 'font-bold text-ink' : 'text-faint', i % 2 && !active ? 'invisible sm:visible' : '')}>
                  {date.getDate()}/{date.getMonth() + 1}
                </span>
              </div>
            )
          })}
        </div>
      </div>
    </div>
  )
}
