import { X } from 'lucide-react'
import { useEffect, type ReactNode } from 'react'
import { createPortal } from 'react-dom'

/** Side sheet on the end edge (left in RTL) for record details. */
export function Drawer({ open, onClose, title, children, footer }: { open: boolean; onClose: () => void; title: string; children: ReactNode; footer?: ReactNode }) {
  useEffect(() => {
    if (!open) return
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && onClose()
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [open, onClose])

  if (!open) return null
  // Portal: a transformed ancestor (entrance animations) would otherwise trap `fixed` inside it.
  return createPortal(
    <div className="fixed inset-0 z-40" role="dialog" aria-modal="true" aria-label={title}>
      <div className="absolute inset-0 bg-ink/40 backdrop-blur-[2px]" onClick={onClose} />
      <aside className="animate-slide-in absolute inset-y-0 end-0 flex w-full max-w-[540px] flex-col bg-canvas shadow-pop">
        <header className="flex h-16 shrink-0 items-center gap-3 border-b border-line bg-white px-5">
          <h2 className="flex-1 truncate text-lg font-extrabold">{title}</h2>
          <button onClick={onClose} aria-label="إغلاق" className="flex size-9 items-center justify-center rounded-xl text-faint hover:bg-black/5 hover:text-ink">
            <X className="size-5" />
          </button>
        </header>
        <div className="flex-1 overflow-y-auto p-5">{children}</div>
        {footer && <footer className="flex shrink-0 flex-wrap gap-2.5 border-t border-line bg-white p-4">{footer}</footer>}
      </aside>
    </div>,
    document.body,

  )
}
