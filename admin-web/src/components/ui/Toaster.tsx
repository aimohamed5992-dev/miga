import clsx from 'clsx'
import { CircleAlert, CircleCheck } from 'lucide-react'
import { useCallback, useRef, useState, type ReactNode } from 'react'
import { ToastContext, type ToastTone } from '../../lib/toast'

interface Item {
  id: number
  message: string
  tone: ToastTone
}

export function Toaster({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<Item[]>([])
  const next = useRef(0)

  const toast = useCallback((message: string, tone: ToastTone = 'ok') => {
    const id = ++next.current
    setItems((list) => [...list.slice(-2), { id, message, tone }])
    setTimeout(() => setItems((list) => list.filter((i) => i.id !== id)), tone === 'error' ? 6000 : 3500)
  }, [])

  return (
    <ToastContext.Provider value={toast}>
      {children}
      <div className="pointer-events-none fixed inset-x-0 bottom-6 z-[60] flex flex-col items-center gap-2 px-4" aria-live="polite">
        {items.map((t) => (
          <div
            key={t.id}
            className={clsx(
              'animate-fade-up pointer-events-auto flex max-w-md items-center gap-2.5 rounded-2xl px-4 py-3 text-sm font-bold shadow-pop',
              t.tone === 'ok' ? 'bg-brand-700 text-white' : 'bg-white text-brand-700 ring-2 ring-brand-600',
            )}
          >
            {t.tone === 'ok' ? <CircleCheck className="size-5 shrink-0 text-white" /> : <CircleAlert className="size-5 shrink-0" />}
            {t.message}
          </div>
        ))}
      </div>
    </ToastContext.Provider>
  )
}
