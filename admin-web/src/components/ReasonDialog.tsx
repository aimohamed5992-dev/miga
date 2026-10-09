import clsx from 'clsx'
import { useState, type ReactNode } from 'react'
import { ApiError } from '../lib/api'
import { Button } from './ui/Button'
import { Modal } from './ui/Modal'

/**
 * Asks for a reason the affected user will read (reject, suspend, cancel…), with one-tap suggestions.
 * `onSubmit` runs the API call; errors stay in the dialog so the admin can fix and retry.
 */
export function ReasonDialog({
  open,
  onClose,
  title,
  description,
  icon,
  suggestions = [],
  confirmLabel,
  placeholder = 'اكتب السبب بوضوح، سيظهر للمستخدم',
  onSubmit,
}: {
  open: boolean
  onClose: () => void
  title: string
  description?: ReactNode
  icon?: ReactNode
  suggestions?: string[]
  confirmLabel: string
  placeholder?: string
  onSubmit: (reason: string) => Promise<unknown>
}) {
  const [reason, setReason] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const valid = reason.trim().length >= 3

  function close() {
    setReason('')
    setError(null)
    onClose()
  }

  async function submit() {
    if (!valid || busy) return
    setBusy(true)
    setError(null)
    try {
      await onSubmit(reason.trim())
      setReason('')
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'تعذّر تنفيذ العملية')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      open={open}
      onClose={close}
      title={title}
      icon={icon}
      tone="danger"
      busy={busy}
      footer={
        <>
          <Button variant="secondary" onClick={close} disabled={busy}>
            رجوع
          </Button>
          <Button variant="danger" onClick={submit} loading={busy} disabled={!valid}>
            {confirmLabel}
          </Button>
        </>
      }
    >
      {description && <p className="mb-4 text-sm leading-7 text-muted">{description}</p>}
      {suggestions.length > 0 && (
        <div className="mb-3 flex flex-wrap gap-2">
          {suggestions.map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => setReason(s)}
              className={clsx(
                'rounded-full border px-3 py-1.5 text-xs font-bold transition-colors',
                reason === s ? 'border-danger bg-danger-soft text-danger' : 'border-line text-ink-3 hover:border-danger/40',
              )}
            >
              {s}
            </button>
          ))}
        </div>
      )}
      <textarea
        value={reason}
        onChange={(e) => setReason(e.target.value.slice(0, 500))}
        placeholder={placeholder}
        rows={3}
        autoFocus
        className="w-full resize-none rounded-2xl border border-line bg-white p-3.5 text-[15px] outline-none placeholder:text-faint focus:border-brand-400 focus:ring-4 focus:ring-brand-100"
      />
      <div className="mt-1 flex justify-between text-xs">
        <span className="text-danger">{error}</span>
        <span className="num text-faint">{reason.length}/500</span>
      </div>
    </Modal>
  )
}
