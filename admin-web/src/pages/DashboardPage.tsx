import clsx from 'clsx'
import {
  ArrowUpLeft,
  BadgeCheck,
  Bike,
  CircleDollarSign,
  Megaphone,
  PackageX,
  Percent,
  ShoppingBag,
  Store,
  Truck,
  UserX,
  Users,
  Wallet,
  type LucideIcon,
} from 'lucide-react'
import { useState, type ReactNode } from 'react'
import { Link } from 'react-router-dom'
import { useAuth } from '../auth/authState'
import { RevenueChart } from '../components/charts/RevenueChart'
import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import { Illustration } from '../components/ui/Illustration'
import { Button } from '../components/ui/Button'
import { ApiError } from '../lib/api'
import { fmt } from '../lib/format'
import { useDashboard, useRecentOrders } from '../lib/queries'
import { label, orderStatus, type DashboardCounts, type TopStore } from '../lib/types'

const longDate = new Intl.DateTimeFormat('ar', { weekday: 'long', day: 'numeric', month: 'long' })

function Skeleton({ className }: { className?: string }) {
  return <div className={clsx('animate-pulse rounded-xl bg-black/[0.06]', className)} />
}

function SectionTitle({ title, sub, action }: { title: string; sub?: string; action?: ReactNode }) {
  return (
    <div className="mb-5 flex items-start justify-between gap-4">
      <div>
        <h2 className="text-lg font-extrabold">{title}</h2>
        {sub && <p className="mt-0.5 text-sm text-muted">{sub}</p>}
      </div>
      {action}
    </div>
  )
}

function MoreLink({ to, children = 'عرض الكل' }: { to: string; children?: ReactNode }) {
  return (
    <Link to={to} className="inline-flex shrink-0 items-center gap-1 text-sm font-bold text-brand-600 hover:text-brand-700">
      {children} <ArrowUpLeft className="size-4" />
    </Link>
  )
}

function Hero({ counts }: { counts?: DashboardCounts }) {
  const { account } = useAuth()
  const [now] = useState(() => new Date())
  const greeting = now.getHours() < 12 ? 'صباح الخير' : 'مساء الخير'
  return (
    <div className="relative overflow-hidden rounded-card bg-gradient-to-l from-brand-600 to-brand-800 p-7 text-white shadow-brand sm:p-9">
      <div
        className="absolute inset-0"
        style={{ background: 'radial-gradient(600px 300px at 0% 120%, rgba(255,255,255,.16), transparent 65%)' }}
      />
      <img src="/brand/logo-white.png" alt="" className="pointer-events-none absolute -bottom-16 -left-10 size-72 opacity-[0.08]" />
      <Illustration name="admin_dash_welcome" hideIfMissing className="absolute inset-y-0 end-0 hidden h-full w-[55%] object-cover object-left opacity-90 md:block" />
      <div className="relative max-w-xl">
        <p className="text-sm font-medium text-white/75">{longDate.format(now)}</p>
        <h2 className="mt-2 text-2xl font-extrabold sm:text-3xl">
          {greeting}، {account?.fullName || 'مدير ميجا'} 👋
        </h2>
        <p className="mt-3 leading-7 text-white/85">
          {counts ? (
            <>
              اليوم <b className="num text-white">{fmt.int(counts.ordersToday)}</b> طلب، و<b className="num text-white">{fmt.int(counts.activeCampaigns)}</b> حملة
              نشطة، و<b className="num text-white">{fmt.int(counts.driversOnline)}</b> مندوب متصل الآن.
            </>
          ) : (
            'جارٍ تحميل ملخص اليوم…'
          )}
        </p>
      </div>
    </div>
  )
}

function Kpi({
  icon: Icon,
  label: title,
  value,
  sub,
  to,
  accent,
}: {
  icon: LucideIcon
  label: string
  value?: string
  sub?: ReactNode
  to: string
  accent?: boolean
}) {
  return (
    <Link to={to} className="group block">
      <Card className="h-full p-5 transition-all group-hover:-translate-y-0.5 group-hover:shadow-pop">
        <div className="flex items-center justify-between">
          <span
            className={clsx(
              'flex size-11 items-center justify-center rounded-2xl',
              accent ? 'bg-brand-600 text-white shadow-brand' : 'bg-brand-50 text-brand-600',
            )}
          >
            <Icon className="size-5" />
          </span>
          <ArrowUpLeft className="size-4 text-faint opacity-0 transition-opacity group-hover:opacity-100" />
        </div>
        <p className="mt-4 text-sm font-medium text-muted">{title}</p>
        {value === undefined ? <Skeleton className="mt-2 h-8 w-32" /> : <p className="num mt-1 text-[26px] leading-tight font-extrabold">{value}</p>}
        {sub && <p className="mt-1.5 text-xs text-muted">{sub}</p>}
      </Card>
    </Link>
  )
}

function Attention({ counts }: { counts?: DashboardCounts }) {
  if (!counts) return <Skeleton className="h-72" />
  const items = [
    {
      to: '/verifications',
      icon: BadgeCheck,
      title: 'طلبات توثيق بانتظار المراجعة',
      detail: `${fmt.int(counts.merchantsPending)} تاجر · ${fmt.int(counts.driversPending)} مندوب`,
      n: counts.merchantsPending + counts.driversPending,
    },
    {
      to: '/deliveries',
      icon: PackageX,
      title: 'توصيلات متعثرة',
      detail: 'إعادة المحاولة أو استرداد المبلغ للعميل',
      n: counts.failedDeliveries,
    },
    {
      to: '/payouts',
      icon: Wallet,
      title: 'طلبات تحويل أرباح',
      detail: fmt.money(counts.payoutsRequestedAmount),
      n: counts.payoutsRequested,
    },
  ]
  const open = items.filter((i) => i.n > 0)

  return (
    <Card className="flex h-full flex-col p-6">
      <SectionTitle title="يحتاج إجراء" sub={open.length ? 'مهام بانتظارك الآن' : 'لا توجد مهام معلّقة'} />
      {open.length === 0 ? (
        <div className="flex flex-1 flex-col items-center justify-center text-center">
          <Illustration name="admin_dash_all_clear" className="size-40" />
          <p className="mt-4 font-bold">كل شيء تحت السيطرة</p>
          <p className="mt-1 text-sm text-muted">لا توثيقات أو توصيلات متعثرة أو تحويلات معلّقة.</p>
        </div>
      ) : (
        <ul className="space-y-2.5">
          {open.map(({ to, icon: Icon, title, detail, n }) => (
            <li key={to}>
              <Link to={to} className="group flex items-center gap-3.5 rounded-2xl border border-line p-3.5 transition-colors hover:border-brand-200 hover:bg-brand-50/40">
                <span className="flex size-11 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600">
                  <Icon className="size-5" />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-bold">{title}</span>
                  <span className="num block truncate text-xs text-muted">{detail}</span>
                </span>
                <span className="num rounded-full bg-brand-600 px-2.5 py-0.5 text-sm font-extrabold text-white">{fmt.int(n)}</span>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </Card>
  )
}

function TopStores({ stores }: { stores?: TopStore[] }) {
  return (
    <Card className="p-6">
      <SectionTitle title="أعلى المتاجر مبيعًا" sub="آخر 14 يومًا" />
      {!stores ? (
        <div className="space-y-4">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-10" />
          ))}
        </div>
      ) : stores.length === 0 ? (
        <div className="flex flex-col items-center py-6 text-center">
          <Illustration name="admin_empty_list" className="size-28" />
          <p className="mt-3 text-sm text-muted">لا توجد مبيعات مدفوعة في آخر 14 يومًا.</p>
        </div>
      ) : (
        <ol className="space-y-4">
          {stores.map((s, i) => {
            const share = (s.gmv / stores[0].gmv) * 100
            return (
              <li key={s.storeId}>
                <div className="flex items-center gap-3">
                  <span className={clsx('num flex size-7 shrink-0 items-center justify-center rounded-lg text-xs font-extrabold', i === 0 ? 'bg-brand-600 text-white' : 'bg-black/5 text-ink-3')}>
                    {i + 1}
                  </span>
                  <span className="min-w-0 flex-1 truncate text-sm font-bold">{s.storeName}</span>
                  <span className="num text-sm font-extrabold">{fmt.money(s.gmv)}</span>
                </div>
                <div className="ms-10 mt-2 flex items-center gap-3">
                  <div className="h-2 flex-1 overflow-hidden rounded-full bg-black/[0.05]">
                    <div className="h-full rounded-full bg-brand-600 transition-all duration-700" style={{ width: `${share}%`, opacity: 1 - i * 0.15 }} />
                  </div>
                  <span className="num w-14 text-end text-xs text-muted">{fmt.int(s.orders)} طلب</span>
                </div>
              </li>
            )
          })}
        </ol>
      )}
    </Card>
  )
}

function Stat({ icon: Icon, label: title, value, tone = 'neutral', to }: { icon: LucideIcon; label: string; value?: number; tone?: 'neutral' | 'ok' | 'danger'; to: string }) {
  return (
    <Link to={to} className="flex items-center gap-3 rounded-2xl p-3 transition-colors hover:bg-black/[0.03]">
      <span
        className={clsx(
          'flex size-10 shrink-0 items-center justify-center rounded-xl',
          tone === 'ok' ? 'bg-brand-50 text-brand-600' : tone === 'danger' ? 'bg-brand-600 text-white' : 'bg-black/5 text-ink-3',
        )}
      >
        <Icon className="size-[18px]" />
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-xs text-muted">{title}</span>
        {value === undefined ? <Skeleton className="mt-1 h-5 w-10" /> : <span className="num block text-lg leading-tight font-extrabold">{fmt.int(value)}</span>}
      </span>
    </Link>
  )
}

function Platform({ counts }: { counts?: DashboardCounts }) {
  return (
    <Card className="p-6">
      <SectionTitle title="المنصة الآن" sub="الحسابات والعمليات الجارية" />
      <div className="grid grid-cols-2 gap-1">
        <Stat icon={Users} label="العملاء" value={counts?.customers} to="/customers" />
        <Stat icon={Store} label="التجار الموثّقون" value={counts?.merchants} to="/merchants" />
        <Stat icon={Bike} label="المناديب الموثّقون" value={counts?.drivers} to="/drivers" />
        <Stat icon={Bike} label="مناديب متصلون" value={counts?.driversOnline} tone="ok" to="/map" />
        <Stat icon={Truck} label="توصيلات جارية" value={counts?.deliveriesInProgress} tone="ok" to="/deliveries" />
        <Stat icon={Store} label="متاجر نشطة" value={counts?.activeStores} to="/merchants" />
        <Stat icon={UserX} label="حسابات موقوفة" value={counts?.suspendedUsers} tone={counts?.suspendedUsers ? 'danger' : 'neutral'} to="/customers" />
        <Stat icon={Megaphone} label="حملات مكتملة (30 يوم)" value={counts?.campaignsCompleted30d} to="/campaigns" />
      </div>
    </Card>
  )
}

function RecentOrders() {
  const { data, isError } = useRecentOrders(6)
  return (
    <Card className="overflow-hidden">
      <div className="px-6 pt-6">
        <SectionTitle title="أحدث الطلبات" sub="طلبات العملاء على الحملات" action={<MoreLink to="/orders" />} />
      </div>
      {isError ? (
        <p className="px-6 pb-6 text-sm text-danger">تعذّر تحميل الطلبات.</p>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-sm">
            <thead>
              <tr className="border-y border-line bg-canvas/60 text-start text-xs text-muted">
                <th className="px-6 py-3 text-start font-bold">الطلب</th>
                <th className="px-3 py-3 text-start font-bold">العميل</th>
                <th className="px-3 py-3 text-start font-bold">الحملة</th>
                <th className="px-3 py-3 text-start font-bold">المبلغ</th>
                <th className="px-3 py-3 text-start font-bold">الحالة</th>
                <th className="px-6 py-3 text-end font-bold">الوقت</th>
              </tr>
            </thead>
            <tbody>
              {!data
                ? [0, 1, 2, 3].map((i) => (
                    <tr key={i} className="border-b border-line/60">
                      <td colSpan={6} className="px-6 py-3.5">
                        <Skeleton className="h-6" />
                      </td>
                    </tr>
                  ))
                : data.items.map((o) => {
                    const [text, tone] = label(orderStatus, o.status)
                    return (
                      <tr key={o.id} className="border-b border-line/60 last:border-0 hover:bg-canvas/50">
                        <td className="num px-6 py-3.5 font-bold" dir="ltr">
                          <span className="block text-end">{o.number}</span>
                        </td>
                        <td className="px-3 py-3.5">
                          <p className="font-bold">{o.customerName}</p>
                          <p className="num text-xs text-muted">{fmt.phone(o.customerPhone)}</p>
                        </td>
                        <td className="max-w-56 px-3 py-3.5">
                          <p className="truncate">{o.campaignTitle}</p>
                          <p className="truncate text-xs text-muted">{o.storeName}</p>
                        </td>
                        <td className="num px-3 py-3.5 font-bold whitespace-nowrap">{fmt.money(o.totalAmount)}</td>
                        <td className="px-3 py-3.5">
                          <Badge tone={tone} dot>
                            {text}
                          </Badge>
                        </td>
                        <td className="px-6 py-3.5 text-end text-xs whitespace-nowrap text-muted">{fmt.ago(o.createdAt)}</td>
                      </tr>
                    )
                  })}
              {data?.items.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-6 py-10 text-center text-muted">
                    لا توجد طلبات بعد.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  )
}

export function DashboardPage() {
  const { data, error, refetch, isFetching } = useDashboard()
  const c = data?.counts
  const days = data?.days
  const total14 = days?.reduce((s, d) => s + d.gmv, 0) ?? 0
  const orders14 = days?.reduce((s, d) => s + d.orders, 0) ?? 0

  if (error && !data) {
    const offline = error instanceof ApiError && error.isNetwork
    return (
      <Card className="mx-auto mt-10 flex max-w-lg flex-col items-center p-10 text-center">
        <Illustration name={offline ? 'admin_error_offline' : 'admin_empty_list'} className="size-44" />
        <h2 className="mt-6 text-xl font-extrabold">تعذّر تحميل لوحة المعلومات</h2>
        <p className="mt-2 text-muted">{error.message}</p>
        <Button className="mt-6" loading={isFetching} onClick={() => refetch()}>
          إعادة المحاولة
        </Button>
      </Card>
    )
  }

  return (
    <div className="mx-auto max-w-[1400px] space-y-6">
      <div className="animate-fade-up">
        <Hero counts={c} />
      </div>

      <div className="animate-fade-up grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4" style={{ animationDelay: '60ms' }}>
        <Kpi accent icon={CircleDollarSign} label="المبيعات (30 يومًا)" value={c && fmt.money(c.gmv30d)} sub="مدفوعات العملاء المكتملة" to="/orders" />
        <Kpi icon={Percent} label="عمولة المنصة (30 يومًا)" value={c && fmt.money(c.commission30d)} sub="من الطلبات المجمّعة للتجار" to="/payouts" />
        <Kpi icon={ShoppingBag} label="طلبات اليوم" value={c && fmt.int(c.ordersToday)} sub="طلبات مدفوعة منذ منتصف الليل" to="/orders" />
        <Kpi
          icon={Megaphone}
          label="الحملات النشطة"
          value={c && fmt.int(c.activeCampaigns)}
          sub={c && `${fmt.int(c.campaignsCompleted30d)} حملة اكتملت خلال 30 يومًا`}
          to="/campaigns"
        />
      </div>

      <div className="animate-fade-up grid grid-cols-1 gap-6 xl:grid-cols-3" style={{ animationDelay: '120ms' }}>
        <Card className="p-6 xl:col-span-2">
          <SectionTitle
            title="المبيعات اليومية"
            sub="آخر 14 يومًا — المدفوعات المكتملة"
            action={
              days && (
                <div className="flex gap-5 text-end">
                  <div>
                    <p className="text-xs text-muted">الإجمالي</p>
                    <p className="num font-extrabold">{fmt.money(total14)}</p>
                  </div>
                  <div className="hidden sm:block">
                    <p className="text-xs text-muted">الطلبات</p>
                    <p className="num font-extrabold">{fmt.int(orders14)}</p>
                  </div>
                  <div className="hidden sm:block">
                    <p className="text-xs text-muted">متوسط الطلب</p>
                    <p className="num font-extrabold">{fmt.money(orders14 ? total14 / orders14 : 0)}</p>
                  </div>
                </div>
              )
            }
          />
          {days ? <RevenueChart days={days} /> : <Skeleton className="h-64" />}
        </Card>
        <Attention counts={c} />
      </div>

      <div className="animate-fade-up grid grid-cols-1 gap-6 xl:grid-cols-2" style={{ animationDelay: '180ms' }}>
        <TopStores stores={data?.topStores} />
        <Platform counts={c} />
      </div>

      <div className="animate-fade-up" style={{ animationDelay: '240ms' }}>
        <RecentOrders />
      </div>

    </div>
  )
}
