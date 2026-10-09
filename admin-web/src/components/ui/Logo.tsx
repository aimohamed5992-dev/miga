import clsx from 'clsx'

/** Logo mark + wordmark. `light` for dark backgrounds. */
export function Logo({ light, size = 40, className, badge = true }: { light?: boolean; size?: number; className?: string; badge?: boolean }) {
  return (
    <div className={clsx('flex items-center gap-3', className)}>
      <img src={light ? '/brand/logo-white.png' : '/brand/logo.png'} alt="ميجا" width={size} height={size} className="shrink-0" />
      <span className={clsx('text-2xl font-extrabold tracking-tight', light ? 'text-white' : 'text-ink')}>ميجا</span>
      {badge && <span className={clsx('rounded-full px-2.5 py-0.5 text-xs font-bold', light ? 'bg-white text-brand-700' : 'bg-brand-600 text-white')}>الإدارة</span>}
    </div>
  )
}
