import clsx from 'clsx'
import { Bike, Clock, Eye, Phone, Store } from 'lucide-react'
import { Link, useSearchParams } from 'react-router-dom'
import { AccountActions } from '../components/AccountActions'
import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import { Avatar, EmptyState, Skeleton, Tabs } from '../components/ui/ListControls'
import { fmt } from '../lib/format'
import { useDashboard, useVerifications } from '../lib/queries'
import { vehicleLabel, type VerificationItem } from '../lib/types'

type Status = 'pending' | 'rejected' | 'verified'
type Kind = 'all' | 'merchant' | 'driver'

function Row({ label, value, mono }: { label: string; value: string | null | undefined; mono?: boolean }) {
  return (
    <div className="flex items-baseline justify-between gap-3 py-1.5 text-sm">
      <dt className="shrink-0 text-muted">{label}</dt>
      <dd className={clsx('truncate text-end font-bold', mono && 'num', !value && 'font-normal text-faint')} dir={mono ? 'ltr' : undefined}>
        {value || 'غير مُدخل'}
      </dd>
    </div>
  )
}

function VerificationCard({ item }: { item: VerificationItem }) {
  const merchant = item.type === 'merchant'
  const usersPath = merchant ? '/merchants' : '/drivers'
  return (
    <Card className="flex flex-col p-5">
      <div className="flex items-start gap-3.5">
        <Avatar name={item.fullName} tone={merchant ? 'brand' : 'dark'} />
        <div className="min-w-0 flex-1">
          <p className="truncate font-extrabold">{item.fullName}</p>
          <a href={`tel:${item.phone}`} className="num inline-flex items-center gap-1 text-sm text-muted hover:text-brand-600" dir="ltr">
            <Phone className="size-3.5" /> {fmt.phone(item.phone)}
          </a>
        </div>
        <Badge tone={merchant ? 'brand' : 'info'} icon={merchant ? <Store className="size-3.5" /> : <Bike className="size-3.5" />}>
          {merchant ? 'تاجر' : 'مندوب'}
        </Badge>
      </div>

      <dl className="mt-4 divide-y divide-line/70 rounded-2xl bg-canvas px-4 py-1.5">
        {merchant ? (
          <>
            <Row label="النشاط التجاري" value={item.businessNameAr} />
            <Row label="السجل التجاري" value={item.commercialRegistrationNumber} mono />
            <Row label="الرقم الضريبي" value={item.taxNumber} mono />
            <Row label="المتجر" value={item.storeName && `${item.storeName}${item.storeCategory ? ` · ${item.storeCategory}` : ''}`} />
          </>
        ) : (
          <>
            <Row label="رقم الهوية" value={item.nationalId} mono />
            <Row label="رخصة القيادة" value={item.drivingLicenseNumber} mono />
            <Row label="المدينة" value={item.city} />
            <Row
              label="المركبة"
              value={[item.vehicleType && (vehicleLabel[item.vehicleType] ?? item.vehicleType), item.vehicleModel].filter(Boolean).join(' · ')}
            />
            <Row label="رقم اللوحة" value={item.plateNumber} mono />
          </>
        )}
      </dl>

      {item.rejectionReason && (
        <p className="mt-3 rounded-xl bg-danger-soft px-3.5 py-2.5 text-sm text-danger">
          <b>سبب الرفض:</b> {item.rejectionReason}
        </p>
      )}

      <p className="mt-3 flex items-center gap-1.5 text-xs text-muted">
        <Clock className="size-3.5" />
        {item.status === 'pending'
          ? `أُرسل ${fmt.ago(item.submittedAt)}`
          : `${item.status === 'verified' ? 'وُثّق' : 'رُفض'} ${fmt.ago(item.reviewedAt ?? item.submittedAt)}`}
      </p>

      <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-line pt-4">
        <AccountActions
          size="sm"
          show="review"
          account={{ id: item.userId, name: item.fullName, kind: item.type, verification: item.status, isActive: true }}
        />
        <Link
          to={`${usersPath}?user=${item.userId}`}
          className="ms-auto inline-flex h-9 items-center gap-1.5 rounded-xl px-3 text-sm font-bold text-muted hover:bg-black/5 hover:text-ink"
        >
          <Eye className="size-4" /> التفاصيل
        </Link>
      </div>
    </Card>
  )
}

export function VerificationsPage() {
  const [params, setParams] = useSearchParams()
  const status = (params.get('status') as Status) || 'pending'
  const kind = (params.get('type') as Kind) || 'all'
  const { data, isLoading, error } = useVerifications(kind, status)
  const counts = useDashboard().data?.counts

  const set = (k: string, v: string, def: string) =>
    setParams(
      (p) => {
        if (v === def) p.delete(k)
        else p.set(k, v)
        return p
      },
      { replace: true },
    )

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="mb-6 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <Tabs<Status>
          value={status}
          onChange={(v) => set('status', v, 'pending')}
          options={[
            { value: 'pending', label: 'بانتظار المراجعة', count: counts && counts.merchantsPending + counts.driversPending },
            { value: 'rejected', label: 'مرفوضة' },
            { value: 'verified', label: 'موثّقة' },
          ]}
        />
        <Tabs<Kind>
          value={kind}
          onChange={(v) => set('type', v, 'all')}
          options={[
            { value: 'all', label: 'الكل' },
            { value: 'merchant', label: 'التجار', count: status === 'pending' ? counts?.merchantsPending : undefined },
            { value: 'driver', label: 'المناديب', count: status === 'pending' ? counts?.driversPending : undefined },
          ]}
        />
      </div>

      {status === 'pending' && (
        <p className="mb-5 text-sm text-muted">الأقدم أولًا. راجع البيانات ثم وثّق الحساب أو ارفضه مع سبب واضح يظهر لصاحبه في التطبيق.</p>
      )}

      {error ? (
        <Card>
          <EmptyState image="admin_error_offline" title="تعذّر تحميل الطلبات" text={error.message} />
        </Card>
      ) : isLoading ? (
        <div className="grid gap-5 md:grid-cols-2 2xl:grid-cols-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-80" />
          ))}
        </div>
      ) : data!.length === 0 ? (
        <Card>
          <EmptyState
            image={status === 'pending' ? 'admin_empty_verifications' : 'admin_empty_list'}
            title={status === 'pending' ? 'لا توجد طلبات بانتظار المراجعة' : status === 'rejected' ? 'لا توجد طلبات مرفوضة' : 'لا توجد حسابات موثّقة بعد'}
            text={status === 'pending' ? 'ستظهر هنا تسجيلات التجار والمناديب الجديدة فور إرسالها.' : undefined}
          />
        </Card>
      ) : (
        <div className="grid gap-5 md:grid-cols-2 2xl:grid-cols-3">
          {data!.map((item, i) => (
            <div key={item.userId} className="animate-fade-up" style={{ animationDelay: `${Math.min(i, 8) * 40}ms` }}>
              <VerificationCard item={item} />
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
