import clsx from 'clsx'
import { ArrowLeft, KeyRound, Pencil, ShieldCheck, Smartphone } from 'lucide-react'
import { useEffect, useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../auth/authState'
import { Button } from '../components/ui/Button'
import { Field } from '../components/ui/Field'
import { OtpInput } from '../components/ui/OtpInput'
import { ApiError, auth, type OtpSent } from '../lib/api'
import { fmt } from '../lib/format'

const YEAR = new Date().getFullYear()

/** Two-step indicator at the top of the card. */
function Steps({ step }: { step: 1 | 2 }) {
  return (
    <div className="flex items-center gap-3 text-xs font-bold">
      {(['رقم الجوال', 'رمز التحقق'] as const).map((label, i) => {
        const n = (i + 1) as 1 | 2
        const done = step > n
        const active = step === n
        return (
          <div key={label} className="flex flex-1 flex-col gap-2">
            <div className={clsx('h-1.5 rounded-full transition-colors duration-500', done || active ? 'bg-brand-600' : 'bg-black/[0.07]')} />
            <span className={clsx(active ? 'text-brand-700' : done ? 'text-ink-3' : 'text-faint')}>
              <span className="num">{n}.</span> {label}
            </span>
          </div>
        )
      })}
    </div>
  )
}

/** Admin sign-in: Saudi mobile → 4-digit code. Only numbers already registered as admins get in. */
export function LoginPage() {
  const { account, signedIn } = useAuth()
  const location = useLocation()
  const [phone, setPhone] = useState('')
  const [code, setCode] = useState('')
  const [sent, setSent] = useState<OtpSent | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [resendIn, setResendIn] = useState(0)

  useEffect(() => {
    if (resendIn <= 0) return
    const t = setTimeout(() => setResendIn((s) => s - 1), 1000)
    return () => clearTimeout(t)
  }, [resendIn])

  if (account) return <Navigate to={(location.state as { from?: string } | null)?.from ?? '/'} replace />

  const phoneValid = /^5\d{8}$/.test(phone)

  async function sendCode(e?: FormEvent) {
    e?.preventDefault()
    if (!phoneValid || busy) return
    setBusy(true)
    setError(null)
    try {
      const r = await auth.sendOtp(`0${phone}`)
      setSent(r)
      setCode('')
      setResendIn(r.resendAfterSeconds)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'تعذّر إرسال الرمز')
    } finally {
      setBusy(false)
    }
  }

  async function verify(value = code, e?: FormEvent) {
    e?.preventDefault()
    if (!sent || value.length !== 4 || busy) return
    setBusy(true)
    setError(null)
    try {
      signedIn(await auth.verifyOtp(sent.phone, value))
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'تعذّر تسجيل الدخول')
      setCode('')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="relative flex min-h-full flex-col overflow-hidden bg-gradient-to-br from-brand-500 via-brand-600 to-brand-800">
      {/* Decoration: dotted texture, the logo mark as a watermark, soft rings */}
      <div
        className="pointer-events-none absolute inset-0 opacity-[0.14]"
        style={{ backgroundImage: 'radial-gradient(rgba(255,255,255,.9) 1px, transparent 1.2px)', backgroundSize: '22px 22px' }}
      />
      <img src="/brand/logo-white.png" alt="" className="pointer-events-none absolute -top-32 -right-32 size-[34rem] rotate-12 opacity-[0.07]" />
      <div className="pointer-events-none absolute -bottom-48 -left-40 size-[36rem] rounded-full border-[70px] border-white/[0.06]" />
      <div className="pointer-events-none absolute -bottom-24 -left-16 size-[22rem] rounded-full border-[36px] border-white/[0.05]" />

      <header className="relative flex items-center justify-between px-6 py-6 sm:px-10">
        <div className="flex items-center gap-3">
          <img src="/brand/logo-white.png" alt="ميجا" className="size-11" />
          <div className="leading-tight text-white">
            <p className="text-xl font-extrabold">ميجا</p>
            <p className="text-xs text-white/75">لوحة الإدارة</p>
          </div>
        </div>
        <span className="hidden rounded-full bg-white/15 px-3.5 py-1.5 text-xs font-bold text-white ring-1 ring-white/20 sm:inline">منصة الشراء الجماعي</span>
      </header>

      <main className="relative flex flex-1 items-center justify-center px-4 py-8">
        <div className="animate-fade-up w-full max-w-[460px] rounded-[28px] bg-white p-7 shadow-[0_40px_80px_-30px_rgb(60_0_8/.6)] sm:p-10">
          <Steps step={sent ? 2 : 1} />

          <div className="mt-8 text-center">
            <span className="mx-auto flex size-16 items-center justify-center rounded-[20px] bg-brand-600 text-white shadow-brand">
              {sent ? <KeyRound className="size-8" /> : <Smartphone className="size-8" />}
            </span>
            <h1 className="mt-5 text-2xl font-extrabold sm:text-[28px]">{sent ? 'أدخل رمز التحقق' : 'مرحبًا بك في لوحة الإدارة'}</h1>
            <p className="mt-2 text-sm leading-6 text-muted">
              {sent ? (
                <>
                  أرسلنا رمزًا من 4 أرقام إلى{' '}
                  <span className="num font-bold text-ink" dir="ltr">
                    {fmt.phone(sent.phone)}
                  </span>
                </>
              ) : (
                'سجّل الدخول برقم الجوال المسجّل كمدير على ميجا'
              )}
            </p>
          </div>

          {!sent ? (
            <form onSubmit={sendCode} className="mt-8 space-y-5">
              <Field
                label="رقم الجوال"
                adornment={<span dir="ltr">🇸🇦 +966</span>}
                dir="ltr"
                inputMode="numeric"
                autoFocus
                placeholder="5X XXX XXXX"
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').replace(/^0/, '').slice(0, 9))}
                className="num text-lg tracking-wider"
                error={error}
              />
              <Button type="submit" size="lg" block loading={busy} disabled={!phoneValid} icon={<ArrowLeft className="size-5" />} className="flex-row-reverse">
                متابعة
              </Button>
            </form>
          ) : (
            <form onSubmit={(e) => verify(code, e)} className="mt-8 space-y-5">
              <OtpInput value={code} onChange={setCode} onComplete={(v) => verify(v)} disabled={busy} error={!!error} autoFocus />
              {error && <p className="text-center text-sm font-medium text-brand-700">{error}</p>}
              {sent.devCode && (
                <p className="rounded-2xl bg-brand-50 px-4 py-2.5 text-center text-sm text-brand-800">
                  بيئة التطوير — الرمز: <span className="num font-extrabold">{sent.devCode}</span>
                </p>
              )}
              <Button type="submit" size="lg" block loading={busy} disabled={code.length !== 4}>
                دخول لوحة التحكم
              </Button>
              <div className="flex items-center justify-between text-sm">
                <button
                  type="button"
                  className="inline-flex items-center gap-1.5 font-bold text-muted hover:text-brand-700"
                  onClick={() => {
                    setSent(null)
                    setError(null)
                  }}
                >
                  <Pencil className="size-3.5" /> تعديل الرقم
                </button>
                <button type="button" disabled={resendIn > 0 || busy} onClick={() => sendCode()} className="font-bold text-brand-600 disabled:text-faint">
                  {resendIn > 0 ? (
                    <>
                      إعادة الإرسال بعد <span className="num">{resendIn}</span> ث
                    </>
                  ) : (
                    'إعادة إرسال الرمز'
                  )}
                </button>
              </div>
            </form>
          )}

          <p className="mt-8 flex items-center justify-center gap-1.5 border-t border-line pt-5 text-xs text-muted">
            <ShieldCheck className="size-4 text-brand-600" /> الدخول مقصور على حسابات الإدارة المعتمدة
          </p>
        </div>
      </main>

      <footer className="relative pb-6 text-center text-xs text-white/70">© ميجا {YEAR}</footer>
    </div>
  )
}
