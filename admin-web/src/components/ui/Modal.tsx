import clsx from 'clsx'
import { X } from 'lucide-react'
import { useEffect, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

/** Centered dialog. Escape or the backdrop closes it unless `busy`. */
export function Modal({
  open,
  onClose,
  title,
  icon,
  tone = 'brand',
  busy,
  children,
  footer,
  className,
}: {
  open: boolean
  onClose: () => void
  title: string
  icon?: ReactNode
  tone?: 'brand' | 'danger' | 'ok'
  busy?: boolean
  children?: ReactNode
  footer?: ReactNode
  className?: string
}) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && !busy && onClose()
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [open, busy, onClose])

  if (!open) return null
  // Portal: a transformed ancestor (entrance animations) would otherwise trap `fixed` inside it.
  return createPortal(
    <div className="fixed inset-0 z-50 flex items-end justify-center p-0 sm:items-center sm:p-6" role="dialog" aria-modal="true" aria-label={title}>
      <div className="absolute inset-0 bg-ink/50 backdrop-blur-sm" onClick={() => !busy && onClose()} />
      <div className={clsx('animate-fade-up relative w-full max-w-lg rounded-t-card bg-white p-6 shadow-pop sm:rounded-card sm:p-7', className)}>
        <div className="flex items-start gap-4">
          {icon && (
            <span
              className={clsx(
                'flex size-12 shrink-0 items-center justify-center rounded-2xl',
                tone === 'danger' ? 'bg-brand-600 text-white' : 'bg-brand-50 text-brand-600',
              )}
            >
              {icon}
            </span>
          )}
          <h2 className="flex-1 pt-2.5 text-lg font-extrabold">{title}</h2>
          <button onClick={onClose} disabled={busy} aria-label="إغلاق" className="flex size-9 items-center justify-center rounded-xl text-faint hover:bg-black/5 hover:text-ink">
            <X className="size-5" />
          </button>
        </div>
        {children && <div className="mt-4">{children}</div>}
        {footer && <div className="mt-6 flex flex-wrap justify-end gap-2.5">{footer}</div>}
      </div>
    </div>,
    document.body,

  )
}
