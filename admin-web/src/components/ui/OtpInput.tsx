import clsx from 'clsx'
import { useRef, type ClipboardEvent, type KeyboardEvent } from 'react'

/**
 * One box per digit. Typing moves forward, Backspace moves back, pasting (or SMS autofill into the first box)
 * spreads the digits. Calls `onComplete` once every box is filled.
 */
export function OtpInput({
  value,
  onChange,
  onComplete,
  length = 4,
  disabled,
  error,
  autoFocus,
}: {
  value: string
  onChange: (v: string) => void
  onComplete?: (v: string) => void
  length?: number
  disabled?: boolean
  error?: boolean
  autoFocus?: boolean
}) {
  const refs = useRef<(HTMLInputElement | null)[]>([])
  const focus = (i: number) => refs.current[Math.max(0, Math.min(length - 1, i))]?.focus()

  function put(at: number, digits: string) {
    const chars = value.padEnd(length, ' ').split('')
    let i = at
    for (const d of digits) {
      if (i >= length) break
      chars[i++] = d
    }
    const next = chars.join('').replace(/\s+$/, '')
    onChange(next)
    focus(i)
    if (next.length === length && !next.includes(' ')) onComplete?.(next)
  }

  function onKey(i: number, e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Backspace') {
      e.preventDefault()
      const chars = value.padEnd(length, ' ').split('')
      const at = chars[i] !== ' ' && i < value.length ? i : i - 1
      if (at < 0) return
      chars[at] = ' '
      onChange(chars.join('').replace(/\s+$/, ''))
      focus(at)
    } else if (e.key === 'ArrowLeft') focus(i + 1) // RTL page, but the code reads left → right
    else if (e.key === 'ArrowRight') focus(i - 1)
  }

  function onPaste(i: number, e: ClipboardEvent<HTMLInputElement>) {
    e.preventDefault()
    const digits = e.clipboardData.getData('text').replace(/\D/g, '')
    if (digits) put(i, digits)
  }

  return (
    <div dir="ltr" className="flex justify-center gap-3">
      {Array.from({ length }, (_, i) => {
        const ch = value[i] && value[i] !== ' ' ? value[i] : ''
        return (
          <input
            key={i}
            ref={(el) => {
              refs.current[i] = el
            }}
            value={ch}
            inputMode="numeric"
            autoComplete={i === 0 ? 'one-time-code' : 'off'}
            autoFocus={autoFocus && i === 0}
            disabled={disabled}
            aria-label={`الرقم ${i + 1}`}
            onFocus={(e) => e.target.select()}
            onKeyDown={(e) => onKey(i, e)}
            onPaste={(e) => onPaste(i, e)}
            onChange={(e) => {
              const digits = e.target.value.replace(/\D/g, '')
              if (digits) put(i, digits.length > 1 && ch ? digits.replace(ch, '') || digits : digits)
            }}
            className={clsx(
              'num size-16 rounded-2xl border-2 bg-white text-center text-3xl font-extrabold text-ink outline-none transition-all sm:size-[72px]',
              'focus:border-brand-600 focus:ring-4 focus:ring-brand-100 disabled:opacity-60',
              error ? 'border-brand-600 bg-brand-50' : ch ? 'border-brand-300' : 'border-line',
            )}
          />
        )
      })}
    </div>
  )
}
