import clsx from 'clsx'
import { ChevronLeft, Star } from 'lucide-react'
import { useCallback, type ReactNode } from 'react'
import { useSearchParams } from 'react-router-dom'
import { UserPanel } from '../components/UserPanel'
import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import { Avatar, EmptyState, Pagination, SearchInput, Skeleton, Tabs } from '../components/ui/ListControls'
import { fmt } from '../lib/format'
import { useDashboard, useUsers, type UserKind } from '../lib/queries'
import { vehicleLabel, verificationLabel, type AdminUser } from '../lib/types'

const PAGE_SIZE = 15

interface Column {
  head: string
  cell: (u: AdminUser) => ReactNode
  className?: string
}

const person = (u: AdminUser, sub?: ReactNode): ReactNode => (
  <div className="flex items-center gap-3">
    <Avatar name={u.fullName} tone={u.isActive ? 'brand' : 'muted'} />
    <div className="min-w-0">
      <p className="truncate font-bold">{u.fullName || 'بدون اسم'}</p>
      <p className="num text-xs text-muted">{sub ?? fmt.phone(u.phone)}</p>
    </div>
  </div>
)

const verificationCell = (u: AdminUser) => {
  const [text, tone] = verificationLabel[u.verification] ?? ['—', 'neutral']
  return <Badge tone={tone}>{text}</Badge>
}

const activeCell = (u: AdminUser) =>
  u.isActive ? (
    <Badge tone="ok" dot>
      نشط
    </Badge>
  ) : (
    <span title={u.suspensionReason ?? undefined}>
      <Badge tone="danger" dot>
        موقوف
      </Badge>
    </span>
  )

const joined: Column = { head: 'التسجيل', cell: (u) => <span className="text-xs text-muted">{fmt.date(u.createdAt)}</span> }

const columns: Record<UserKind, Column[]> = {
  merchant: [
    { head: 'التاجر', cell: (u) => person(u) },
    {
      head: 'النشاط التجاري',
      cell: (u) => (
        <div className="min-w-0">
          <p className="truncate font-medium">{u.businessName || '—'}</p>
          <p className="text-xs text-muted">{fmt.int(u.storesCount)} متجر</p>
        </div>
      ),
    },
    { head: 'التوثيق', cell: verificationCell },
    { head: 'الحساب', cell: activeCell },
    joined,
  ],
  driver: [
    { head: 'المندوب', cell: (u) => person(u) },
    {
      head: 'المدينة والمركبة',
      cell: (u) => (
        <div>
          <p className="font-medium">{u.city || '—'}</p>
          <p className="text-xs text-muted">{u.vehicleType ? (vehicleLabel[u.vehicleType] ?? u.vehicleType) : '—'}</p>
        </div>
      ),
    },
    { head: 'التوثيق', cell: verificationCell },
    {
      head: 'الاتصال',
      cell: (u) =>
        u.verification !== 'verified' ? (
          <span className="text-faint">—</span>
        ) : u.isAvailable && u.isActive ? (
          <Badge tone="ok" dot>
            متصل
          </Badge>
        ) : (
          <Badge dot>غير متصل</Badge>
        ),
    },
    {
      head: 'التوصيلات',
      cell: (u) => (
        <div className="num">
          <p className="font-bold">{fmt.int(u.deliveriesCount)}</p>
          {u.rating != null && (
            <p className="flex items-center gap-1 text-xs text-muted">
              <Star className="size-3 fill-warn text-warn" /> {u.rating.toFixed(1)}
            </p>
          )}
        </div>
      ),
    },
    { head: 'الحساب', cell: activeCell },
  ],
  customer: [
    { head: 'العميل', cell: (u) => person(u) },
    { head: 'الطلبات', cell: (u) => <span className="num font-bold">{fmt.int(u.ordersCount)}</span> },
    { head: 'إجمالي المشتريات', cell: (u) => <span className="num font-bold whitespace-nowrap">{fmt.money(u.totalSpent)}</span> },
    { head: 'الحساب', cell: activeCell },
    joined,
  ],
}

const copy: Record<UserKind, { search: string; empty: string; one: string }> = {
  merchant: { search: 'ابحث بالاسم أو الجوال أو النشاط', empty: 'لا يوجد تجار', one: 'التاجر' },
  driver: { search: 'ابحث بالاسم أو رقم الجوال', empty: 'لا يوجد مناديب', one: 'المندوب' },
  customer: { search: 'ابحث بالاسم أو رقم الجوال', empty: 'لا يوجد عملاء', one: 'العميل' },
}

/** Merchants, drivers or customers: status tabs, search, paged table; a row opens the account panel (?user=id). */
export function UsersPage({ kind }: { kind: UserKind }) {
  const [params, setParams] = useSearchParams()
  const q = params.get('q') ?? ''
  const status = params.get('status') ?? 'all'
  const page = Number(params.get('page') ?? 1) || 1
  const selected = params.get('user')
  const counts = useDashboard().data?.counts
  const { data, isLoading, isFetching, error } = useUsers(kind, q, status, page, PAGE_SIZE)

  const update = useCallback(
    (changes: Record<string, string | null>) =>
      setParams(
        (p) => {
          for (const [k, v] of Object.entries(changes)) {
            if (v === null || v === '') p.delete(k)
            else p.set(k, v)
          }
          return p
        },
        { replace: true },
      ),
    [setParams],
  )
  const onSearch = useCallback((v: string) => update({ q: v, page: null }), [update])

  const tabs =
    kind === 'customer'
      ? [
          { value: 'all', label: 'الكل' },
          { value: 'active', label: 'نشط' },
          { value: 'suspended', label: 'موقوف' },
        ]
      : [
          { value: 'all', label: 'الكل' },
          { value: 'verified', label: 'موثّق' },
          { value: 'pending', label: 'بانتظار المراجعة', count: counts && (kind === 'merchant' ? counts.merchantsPending : counts.driversPending) },
          { value: 'rejected', label: 'مرفوض' },
          { value: 'suspended', label: 'موقوف' },
        ]

  const cols = columns[kind]

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="mb-6 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <Tabs value={status} onChange={(v) => update({ status: v === 'all' ? null : v, page: null })} options={tabs} />
        <SearchInput value={q} onChange={onSearch} placeholder={copy[kind].search} />
      </div>

      <Card className="overflow-hidden">
        {error ? (
          <EmptyState image="admin_error_offline" title="تعذّر تحميل القائمة" text={error.message} />
        ) : !isLoading && data!.items.length === 0 ? (
          <EmptyState
            image={q ? 'admin_empty_search' : 'admin_empty_list'}
            title={q ? 'لا توجد نتائج' : copy[kind].empty}
            text={q ? `لا يوجد ${copy[kind].one} يطابق «${q}».` : 'جرّب تغيير الفلتر.'}
          />
        ) : (
          <>
            <div className={clsx('overflow-x-auto transition-opacity', isFetching && !isLoading && 'opacity-60')}>
              <table className="w-full min-w-[760px] text-sm">
                <thead>
                  <tr className="border-b border-line bg-canvas/60 text-xs text-muted">
                    {cols.map((c) => (
                      <th key={c.head} className="px-4 py-3 text-start font-bold first:ps-6">
                        {c.head}
                      </th>
                    ))}
                    <th className="w-12" />
                  </tr>
                </thead>
                <tbody>
                  {isLoading
                    ? Array.from({ length: 6 }, (_, i) => (
                        <tr key={i} className="border-b border-line/60">
                          <td colSpan={cols.length + 1} className="px-6 py-3">
                            <Skeleton className="h-10" />
                          </td>
                        </tr>
                      ))
                    : data!.items.map((u) => (
                        <tr
                          key={u.id}
                          onClick={() => update({ user: u.id })}
                          className={clsx('cursor-pointer border-b border-line/60 transition-colors last:border-0 hover:bg-brand-50/40', selected === u.id && 'bg-brand-50/60')}
                        >
                          {cols.map((c) => (
                            <td key={c.head} className="max-w-64 px-4 py-3 first:ps-6">
                              {c.cell(u)}
                            </td>
                          ))}
                          <td className="pe-4">
                            <ChevronLeft className="size-4 text-faint" />
                          </td>
                        </tr>
                      ))}
                </tbody>
              </table>
            </div>
            {data && <Pagination page={page} pageSize={PAGE_SIZE} total={data.totalCount} onPage={(p) => update({ page: p === 1 ? null : String(p) })} />}
          </>
        )}
      </Card>

      <UserPanel id={selected} onClose={() => update({ user: null })} />
    </div>
  )
}
