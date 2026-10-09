import clsx from 'clsx'
import { ChevronLeft, ChevronRight, Search, X } from 'lucide-react'
import { useEffect, useState, type ReactNode } from 'react'
import { fmt } from '../../lib/format'
import { Illustration } from './Illustration'

/** Search box that reports after the admin stops typing (350 ms). */
export function SearchInput({ value, onChange, placeholder }: { value: string; onChange: (v: string) => void; placeholder: string }) {
  const [text, setText] = useState(value)
  // Follow outside changes (back button, cleared filter) without an effect.
  const [seen, setSeen] = useState(value)
  if (value !== seen) {
    setSeen(value)
    setText(value)
  }
  useEffect(() => {
    if (text === value) return
    const t = setTimeout(() => onChange(text.trim()), 350)
    return () => clearTimeout(t)
  }, [text, value, onChange])

  return (
    <label className="flex h-11 w-full items-center gap-2 rounded-xl border border-line bg-white px-3.5 transition-all focus-within:border-brand-400 focus-within:ring-4 focus-within:ring-brand-100 sm:w-80">
      <Search className="size-[18px] shrink-0 text-faint" />
      <input value={text} onChange={(e) => setText(e.target.value)} placeholder={placeholder} className="h-full min-w-0 flex-1 bg-transparent text-sm outline-none placeholder:text-faint" />
      {text && (
        <button type="button" onClick={() => setText('')} aria-label="مسح البحث" className="text-faint hover:text-ink">
          <X className="size-4" />
        </button>
      )}
    </label>
  )
}

export interface TabOption<T extends string> {
  value: T
  label: string
  count?: number
}

/** Segmented filter (status tabs). */
export function Tabs<T extends string>({ value, onChange, options }: { value: T; onChange: (v: T) => void; options: TabOption<T>[] }) {
  return (
    <div className="flex max-w-full gap-1 overflow-x-auto rounded-xl bg-black/[0.04] p-1">
      {options.map((o) => (
        <button
          key={o.value}
          type="button"
          onClick={() => onChange(o.value)}
          className={clsx(
            'flex h-9 shrink-0 items-center gap-1.5 rounded-lg px-3.5 text-sm font-bold whitespace-nowrap transition-all',
            o.value === value ? 'bg-white text-ink shadow-card' : 'text-muted hover:text-ink',
          )}
        >
          {o.label}
          {o.count !== undefined && o.count > 0 && (
            <span className={clsx('num rounded-full px-1.5 text-xs', o.value === value ? 'bg-brand-600 text-white' : 'bg-black/10 text-ink-3')}>{fmt.int(o.count)}</span>
          )}
        </button>
      ))}
    </div>
  )
}

export function Pagination({ page, pageSize, total, onPage }: { page: number; pageSize: number; total: number; onPage: (p: number) => void }) {
  const pages = Math.max(1, Math.ceil(total / pageSize))
  if (total === 0) return null
  const from = (page - 1) * pageSize + 1
  const to = Math.min(total, page * pageSize)
  const btn = 'flex size-9 items-center justify-center rounded-xl border border-line bg-white text-ink-3 transition-colors hover:border-brand-300 hover:text-brand-600 disabled:pointer-events-none disabled:opacity-40'
  return (
    <div className="flex items-center justify-between gap-4 px-5 py-4 text-sm">
      <span className="text-muted">
        <span className="num font-bold text-ink">
          {fmt.int(from)}–{fmt.int(to)}
        </span>{' '}
        من <span className="num font-bold text-ink">{fmt.int(total)}</span>
      </span>
      {pages > 1 && (
        <div className="flex items-center gap-2">
          {/* RTL: "previous" points right */}
          <button className={btn} disabled={page <= 1} onClick={() => onPage(page - 1)} aria-label="الصفحة السابقة">
            <ChevronRight className="size-4" />
          </button>
          <span className="num min-w-14 text-center font-bold">
            {page} / {pages}
          </span>
          <button className={btn} disabled={page >= pages} onClick={() => onPage(page + 1)} aria-label="الصفحة التالية">
            <ChevronLeft className="size-4" />
          </button>
        </div>
      )}
    </div>
  )
}

export function EmptyState({ image, title, text, action }: { image: string; title: string; text?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center px-6 py-14 text-center">
      <Illustration name={image} className="size-40" />
      <p className="mt-5 text-lg font-extrabold">{title}</p>
      {text && <p className="mt-1.5 max-w-sm text-sm leading-6 text-muted">{text}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  )
}

export function Avatar({ name, tone = 'brand', size = 'md' }: { name: string; tone?: 'brand' | 'dark' | 'muted'; size?: 'md' | 'lg' }) {
  return (
    <span
      className={clsx(
        'flex shrink-0 items-center justify-center font-extrabold',
        size === 'lg' ? 'size-16 rounded-2xl text-2xl' : 'size-10 rounded-xl text-sm',
        tone === 'brand' ? 'bg-brand-50 text-brand-700' : tone === 'dark' ? 'bg-brand-700 text-white' : 'bg-black/5 text-muted',
      )}
    >
      {name.trim()[0] ?? '؟'}
    </span>
  )
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={clsx('animate-pulse rounded-xl bg-black/[0.06]', className)} />
}
