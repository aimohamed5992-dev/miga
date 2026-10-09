import clsx from 'clsx'
import type { ReactNode } from 'react'

export type Tone = 'neutral' | 'brand' | 'ok' | 'warn' | 'info' | 'danger'

const tones: Record<Tone, string> = {
  neutral: 'bg-black/5 text-muted',
  brand: 'bg-brand-50 text-brand-700',
  ok: 'bg-ok-soft text-ok',
  warn: 'bg-white text-brand-700 ring-1 ring-inset ring-brand-300',
  info: 'bg-brand-50 text-brand-700',
  danger: 'bg-brand-600 text-white',
}

export function Badge({ tone = 'neutral', icon, children, dot }: { tone?: Tone; icon?: ReactNode; children: ReactNode; dot?: boolean }) {
  return (
    <span className={clsx('inline-flex items-center gap-1.5 rounded-full px-2.5 py-1 text-xs font-bold whitespace-nowrap', tones[tone])}>
      {dot && <span className="size-1.5 rounded-full bg-current" />}
      {icon}
      {children}
    </span>
  )
}
