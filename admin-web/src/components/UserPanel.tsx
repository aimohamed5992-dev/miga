import clsx from 'clsx'
import { Ban, CalendarDays, Mail, MapPin, Phone, ShieldAlert, Star } from 'lucide-react'
import type { ReactNode } from 'react'
import { fmt } from '../lib/format'
import { useUser } from '../lib/queries'
import { activityStatus, storeStatus, vehicleLabel, verificationLabel, type AdminUserDetail } from '../lib/types'
import { AccountActions } from './AccountActions'
import { Badge } from './ui/Badge'
import { Drawer } from './ui/Drawer'
import { Avatar, Skeleton } from './ui/ListControls'

const kindOf = (t: number) => (t === 2 ? 'merchant' : t === 3 ? 'driver' : 'customer') as 'merchant' | 'driver' | 'customer'

function Section({ title, children, aside }: { title: string; children: ReactNode; aside?: ReactNode }) {
  return (
    <section className="mt-5">
      <div className="mb-2.5 flex items-center justify-between px-1">
        <h3 className="text-sm font-extrabold text-ink-3">{title}</h3>
        {aside}
      </div>
      <div className="rounded-2xl border border-line/70 bg-white">{children}</div>
    </section>
  )
}

function Info({ label, value, mono }: { label: string; value: ReactNode; mono?: boolean }) {
  return (
    <div className="flex items-baseline justify-between gap-4 border-b border-line/60 px-4 py-3 text-sm last:border-0">
      <span className="shrink-0 text-muted">{label}</span>
      <span className={clsx('min-w-0 truncate text-end font-bold', mono && 'num')} dir={mono ? 'ltr' : undefined}>
        {value || <span className="font-normal text-faint">—</span>}
      </span>
    </div>
  )
}

function Tile({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-2xl border border-line/70 bg-white p-3.5">
      <p className="text-xs text-muted">{label}</p>
      <p className="num mt-1 text-lg font-extrabold">{value}</p>
    </div>
  )
}

function Body({ d }: { d: AdminUserDetail }) {
  const u = d.user
  const kind = kindOf(u.userType)
  const [vText, vTone] = verificationLabel[u.verification] ?? ['—', 'neutral']

  return (
    <>
      {/* identity */}
      <div className="rounded-2xl border border-line/70 bg-white p-5">
        <div className="flex items-start gap-4">
          <Avatar name={u.fullName} size="lg" tone={u.isActive ? (kind === 'driver' ? 'dark' : 'brand') : 'muted'} />
          <div className="min-w-0 flex-1">
            <p className="truncate text-xl font-extrabold">{u.fullName || 'بدون اسم'}</p>
            {kind === 'merchant' && u.businessName && <p className="truncate text-sm text-muted">{u.businessName}</p>}
            <div className="mt-2 flex flex-wrap gap-1.5">
              {kind !== 'customer' && <Badge tone={vTone}>{vText}</Badge>}
              {u.isActive ? (
                <Badge tone="ok" dot>
                  نشط
                </Badge>
              ) : (
                <Badge tone="danger" dot>
                  موقوف
                </Badge>
              )}
              {kind === 'driver' && u.verification === 'verified' && u.isActive && (
                <Badge tone={u.isAvailable ? 'ok' : 'neutral'}>{u.isAvailable ? 'متصل الآن' : 'غير متصل'}</Badge>
              )}
            </div>
          </div>
        </div>
        <div className="mt-4 grid gap-2 text-sm sm:grid-cols-2">
          <a href={`tel:${u.phone}`} className="num flex items-center gap-2 rounded-xl bg-canvas px-3 py-2.5 font-bold hover:text-brand-600" dir="ltr">
            <Phone className="size-4 text-faint" /> {fmt.phone(u.phone)}
          </a>
          <span className="flex items-center gap-2 rounded-xl bg-canvas px-3 py-2.5 text-muted">
            <CalendarDays className="size-4 text-faint" /> انضم {fmt.date(u.createdAt)}
          </span>
          {u.email && (
            <a href={`mailto:${u.email}`} className="flex items-center gap-2 truncate rounded-xl bg-canvas px-3 py-2.5 hover:text-brand-600 sm:col-span-2">
              <Mail className="size-4 shrink-0 text-faint" /> <span className="truncate">{u.email}</span>
            </a>
          )}
        </div>
      </div>

      {!u.isActive && (
        <div className="mt-4 flex gap-3 rounded-2xl bg-danger-soft p-4 text-sm text-danger">
          <ShieldAlert className="size-5 shrink-0" />
          <div>
            <p className="font-extrabold">الحساب موقوف</p>
            <p className="mt-0.5">{u.suspensionReason || 'بدون سبب مسجّل'}</p>
          </div>
        </div>
      )}
      {d.rejectionReason && u.verification === 'rejected' && (
        <div className="mt-4 flex gap-3 rounded-2xl bg-warn-soft p-4 text-sm text-warn">
          <Ban className="size-5 shrink-0" />
          <div>
            <p className="font-extrabold">تم رفض التسجيل — بانتظار تعديل صاحب الحساب</p>
            <p className="mt-0.5">{d.rejectionReason}</p>
          </div>
        </div>
      )}

      {/* numbers */}
      <div className="mt-4 grid grid-cols-3 gap-2.5">
        {kind === 'customer' && (
          <>
            <Tile label="الطلبات" value={fmt.int(u.ordersCount)} />
            <Tile label="المشتريات" value={fmt.money(u.totalSpent)} />
            <Tile label="العناوين" value={fmt.int(d.addresses)} />
          </>
        )}
        {kind === 'merchant' && (
          <>
            <Tile label="المتاجر" value={fmt.int(u.storesCount)} />
            <Tile label="المنتجات" value={fmt.int(d.stores.reduce((s, x) => s + x.products, 0))} />
            <Tile label="الحملات" value={fmt.int(d.stores.reduce((s, x) => s + x.campaigns, 0))} />
          </>
        )}
        {kind === 'driver' && (
          <>
            <Tile label="توصيلات مكتملة" value={fmt.int(u.deliveriesCount)} />
            <Tile
              label="التقييم"
              value={
                <span className="flex items-center gap-1">
                  <Star className="size-4 fill-warn text-warn" /> {u.rating?.toFixed(1) ?? '—'}
                </span>
              }
            />
            <Tile label="المدينة" value={<span className="text-base">{u.city || '—'}</span>} />
          </>
        )}
      </div>

      {kind === 'driver' && (
        <Section title="بيانات المندوب">
          <Info label="رقم الهوية" value={d.nationalId} mono />
          <Info label="رخصة القيادة" value={d.drivingLicenseNumber} mono />
          <Info label="المركبة" value={[u.vehicleType && (vehicleLabel[u.vehicleType] ?? u.vehicleType), d.vehicleModel].filter(Boolean).join(' · ')} />
          <Info label="رقم اللوحة" value={d.plateNumber} mono />
        </Section>
      )}

      {kind === 'merchant' && (
        <>
          <Section title="المتاجر">
            {d.stores.length === 0 ? (
              <p className="px-4 py-5 text-center text-sm text-muted">لم يُنشئ متجرًا بعد.</p>
            ) : (
              d.stores.map((s) => {
                const [t, tone] = storeStatus[s.status] ?? ['—', 'neutral']
                return (
                  <div key={s.id} className="flex items-center gap-3 border-b border-line/60 px-4 py-3 last:border-0">
                    <MapPin className="size-4 shrink-0 text-faint" />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-bold">{s.nameAr}</p>
                      <p className="num text-xs text-muted">
                        {fmt.int(s.products)} منتج · {fmt.int(s.campaigns)} حملة
                      </p>
                    </div>
                    <Badge tone={tone}>{t}</Badge>
                  </div>
                )
              })
            )}
          </Section>
          <Section title="الحساب البنكي">
            <Info label="البنك" value={d.bankName} />
            <Info label="الآيبان" value={d.iban} mono />
          </Section>
        </>
      )}

      <Section title={kind === 'customer' ? 'آخر الطلبات' : kind === 'merchant' ? 'آخر الطلبات المجمّعة' : 'آخر التوصيلات'}>
        {d.recent.length === 0 ? (
          <p className="px-4 py-5 text-center text-sm text-muted">لا يوجد نشاط بعد.</p>
        ) : (
          d.recent.map((a) => {
            const [t, tone] = activityStatus[a.status] ?? [a.status, 'neutral']
            return (
              <div key={a.id} className="flex items-center gap-3 border-b border-line/60 px-4 py-3 last:border-0">
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-bold">{a.title}</p>
                  <p className="num text-xs text-muted">
                    <span dir="ltr">{a.number}</span> · {fmt.date(a.date)}
                  </p>
                </div>
                <div className="text-end">
                  <p className="num text-sm font-bold">{fmt.money(a.amount)}</p>
                  <Badge tone={tone}>{t}</Badge>
                </div>
              </div>
            )
          })
        )}
      </Section>
    </>
  )
}

/** Account details side sheet with the admin actions in its footer. */
export function UserPanel({ id, onClose }: { id: string | null; onClose: () => void }) {
  const { data, isLoading, error } = useUser(id)
  const kind = data ? kindOf(data.user.userType) : null
  const title = kind === 'merchant' ? 'تفاصيل التاجر' : kind === 'driver' ? 'تفاصيل المندوب' : kind === 'customer' ? 'تفاصيل العميل' : 'تفاصيل الحساب'

  return (
    <Drawer
      open={!!id}
      onClose={onClose}
      title={title}
      footer={
        data &&
        kind && (
          <AccountActions
            account={{ id: data.user.id, name: data.user.fullName, kind, verification: data.user.verification, isActive: data.user.isActive }}
          />
        )
      }
    >
      {error ? (
        <p className="rounded-2xl bg-danger-soft p-4 text-sm text-danger">{error.message}</p>
      ) : isLoading || !data ? (
        <div className="space-y-4">
          <Skeleton className="h-44" />
          <Skeleton className="h-20" />
          <Skeleton className="h-48" />
        </div>
      ) : (
        <Body d={data} />
      )}
    </Drawer>
  )
}
