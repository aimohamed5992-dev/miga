import { Headphones, LogOut, Mail, MessageCircle, Percent, Phone, Save, ShieldCheck, Truck } from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { useAuth } from '../auth/authState'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { Field } from '../components/ui/Field'
import { Skeleton } from '../components/ui/ListControls'
import { ApiError } from '../lib/api'
import { fmt } from '../lib/format'
import { useAdminActions, useSettings } from '../lib/queries'
import { useToast } from '../lib/toast'
import type { PlatformSettings } from '../lib/types'

interface Form {
  fee: string
  delivery: string
  phone: string
  whatsApp: string
  email: string
}

const toForm = (s: PlatformSettings): Form => ({
  fee: String(s.platformFeePercent),
  delivery: String(s.deliveryFee),
  phone: s.support.phone ?? '',
  whatsApp: s.support.whatsApp ?? '',
  email: s.support.email ?? '',
})

function Section({ icon, title, sub, children }: { icon: ReactNode; title: string; sub: string; children: ReactNode }) {
  return (
    <Card className="p-6">
      <div className="mb-5 flex items-start gap-3.5">
        <span className="flex size-11 shrink-0 items-center justify-center rounded-2xl bg-brand-50 text-brand-600">{icon}</span>
        <div>
          <h2 className="text-lg font-extrabold">{title}</h2>
          <p className="mt-0.5 text-sm text-muted">{sub}</p>
        </div>
      </div>
      {children}
    </Card>
  )
}

function SettingsForm({ settings }: { settings: PlatformSettings }) {
  const actions = useAdminActions()
  const toast = useToast()
  const [form, setForm] = useState<Form>(() => toForm(settings))
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const set = (k: keyof Form) => (e: React.ChangeEvent<HTMLInputElement>) => setForm((f) => ({ ...f, [k]: e.target.value }))

  const fee = Number(form.fee)
  const delivery = Number(form.delivery)
  const changed = JSON.stringify(form) !== JSON.stringify(toForm(settings))
  const feeError = form.fee === '' || isNaN(fee) || fee < 0 || fee > 30 ? 'بين 0 و30٪' : null
  const deliveryError = form.delivery === '' || isNaN(delivery) || delivery < 0 || delivery > 200 ? 'بين 0 و200 ر.س' : null

  async function save() {
    if (feeError || deliveryError) return
    setSaving(true)
    setError(null)
    try {
      await actions.saveSettings({
        platformFeePercent: fee,
        deliveryFee: delivery,
        supportPhone: form.phone.trim() || null,
        supportWhatsApp: form.whatsApp.trim() || null,
        supportEmail: form.email.trim() || null,
      })
      toast('تم حفظ الإعدادات')
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'تعذّر الحفظ')
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="space-y-6">
      <Section icon={<Percent className="size-5" />} title="العمولة والرسوم" sub="تُطبّق على الحملات التي تكتمل بعد الحفظ، ولا تتغير الطلبات السابقة.">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field
            label="عمولة المنصة"
            icon={<Percent className="size-4" />}
            inputMode="decimal"
            value={form.fee}
            onChange={set('fee')}
            error={feeError}
            hint="نسبة من مبيعات كل حملة مكتملة"
            dir="ltr"
            className="num"
          />
          <Field
            label="رسوم التوصيل للمندوب (ر.س)"
            icon={<Truck className="size-4" />}
            inputMode="decimal"
            value={form.delivery}
            onChange={set('delivery')}
            error={deliveryError}
            hint="لكل توصيلة إلى عميل"
            dir="ltr"
            className="num"
          />
        </div>
        {!feeError && (
          <p className="mt-4 rounded-xl bg-canvas px-4 py-3 text-sm text-ink-3">
            مثال: حملة مبيعاتها <b className="num">{fmt.money(10000)}</b> ← عمولة ميجا <b className="num text-brand-700">{fmt.money((10000 * fee) / 100)}</b> ويستلم
            التاجر <b className="num">{fmt.money(10000 - (10000 * fee) / 100)}</b>.
          </p>
        )}
      </Section>

      <Section icon={<Headphones className="size-5" />} title="تواصل الدعم" sub="تظهر في صفحة «المساعدة والدعم» في تطبيقات العملاء والتجار والمناديب.">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="رقم الدعم" icon={<Phone className="size-4" />} placeholder="920000000" value={form.phone} onChange={set('phone')} dir="ltr" className="num" />
          <Field
            label="واتساب"
            icon={<MessageCircle className="size-4" />}
            placeholder="9665XXXXXXXX"
            value={form.whatsApp}
            onChange={set('whatsApp')}
            hint="بالصيغة الدولية بدون +"
            dir="ltr"
            className="num"
          />
          <div className="sm:col-span-2">
            <Field label="البريد الإلكتروني" icon={<Mail className="size-4" />} placeholder="support@miga.sa" value={form.email} onChange={set('email')} dir="ltr" />
          </div>
        </div>
      </Section>

      <div className="sticky bottom-4 z-10 flex flex-wrap items-center gap-3 rounded-2xl border border-line bg-white/95 p-4 shadow-pop backdrop-blur">
        <Button loading={saving} disabled={!changed || !!feeError || !!deliveryError} icon={<Save className="size-4" />} onClick={save}>
          حفظ الإعدادات
        </Button>
        {changed && (
          <Button variant="ghost" onClick={() => setForm(toForm(settings))} disabled={saving}>
            تراجع
          </Button>
        )}
        <span className="ms-auto text-xs text-muted">
          {error ? (
            <span className="font-medium text-danger">{error}</span>
          ) : settings.updatedAt ? (
            <>
              آخر تعديل {fmt.ago(settings.updatedAt)}
              {settings.updatedBy && ` بواسطة ${settings.updatedBy}`}
            </>
          ) : (
            'القيم الحالية من إعدادات الخادم الافتراضية'
          )}
        </span>
      </div>
    </div>
  )
}

export function SettingsPage() {
  const { data, error } = useSettings()
  const { account, signOut } = useAuth()

  return (
    <div className="mx-auto grid max-w-[1100px] gap-6 lg:grid-cols-[1fr_320px]">
      <div>
        {error ? (
          <Card className="p-6 text-danger">{error.message}</Card>
        ) : data ? (
          // Re-mount on save so the form shows the stored values.
          <SettingsForm key={data.updatedAt ?? 'defaults'} settings={data} />
        ) : (
          <div className="space-y-6">
            <Skeleton className="h-64" />
            <Skeleton className="h-64" />
          </div>
        )}
      </div>

      <div className="space-y-6">
        <Card className="p-6">
          <div className="flex items-center gap-3">
            <span className="flex size-12 items-center justify-center rounded-2xl bg-brand-600 text-lg font-extrabold text-white">
              {(account?.fullName || 'م').trim()[0]}
            </span>
            <div className="min-w-0">
              <p className="truncate font-extrabold">{account?.fullName || 'مدير ميجا'}</p>
              <p className="num text-sm text-muted" dir="ltr">
                {account && fmt.phone(account.phoneNumber)}
              </p>
            </div>
          </div>
          <p className="mt-4 flex items-center gap-2 rounded-xl bg-brand-50 px-3 py-2 text-xs font-bold text-brand-700">
            <ShieldCheck className="size-4" /> صلاحيات مدير كاملة
          </p>
          <Button variant="secondary" block className="mt-4 hover:!border-danger/40 hover:!text-danger" icon={<LogOut className="size-4" />} onClick={signOut}>
            تسجيل الخروج
          </Button>
        </Card>
        <Card className="p-6 text-sm leading-7 text-muted">
          <p className="font-extrabold text-ink">ملاحظات</p>
          <ul className="mt-2 list-inside list-disc space-y-1">
            <li>تعديل العمولة لا يؤثر على أرباح التجار عن الطلبات السابقة.</li>
            <li>رسوم التوصيل تُحتسب للمندوب عند إنشاء التوصيلة.</li>
            <li>حساب المدير الأول يُنشأ من إعداد الخادم <span dir="ltr">Seed:AdminPhone</span>، ولا توجد بعد شاشة لإضافة مديرين.</li>
          </ul>
        </Card>
      </div>
    </div>
  )
}
