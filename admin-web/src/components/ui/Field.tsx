import clsx from 'clsx'
import { forwardRef, type InputHTMLAttributes, type ReactNode } from 'react'

interface Props extends Omit<InputHTMLAttributes<HTMLInputElement>, 'prefix'> {
  label?: string
  hint?: string
  error?: string | null
  icon?: ReactNode
  /** Fixed text inside the field on the start side (e.g. +966). */
  adornment?: ReactNode
}

export const Field = forwardRef<HTMLInputElement, Props>(function Field({ label, hint, error, icon, adornment, className, dir, ...rest }, ref) {
  return (
    <label className="block">
      {label && <span className="mb-2 block text-sm font-bold text-ink-3">{label}</span>}
      <span
        className={clsx(
          'flex h-13 items-center gap-2 rounded-2xl border bg-white px-4 transition-all',
          'focus-within:border-brand-400 focus-within:ring-4 focus-within:ring-brand-100',
          error ? 'border-danger' : 'border-line',
        )}
      >
        {icon && <span className="text-faint">{icon}</span>}
        {adornment && <span className="border-e border-line pe-3 text-sm font-bold text-ink-3">{adornment}</span>}
        <input
          ref={ref}
          dir={dir}
          className={clsx('h-full min-w-0 flex-1 bg-transparent text-[15px] font-medium outline-none placeholder:text-faint', className)}
          {...rest}
        />
      </span>
      {error ? (
        <span className="mt-1.5 block text-xs font-medium text-danger">{error}</span>
      ) : (
        hint && <span className="mt-1.5 block text-xs text-muted">{hint}</span>
      )}
    </label>
  )
})
