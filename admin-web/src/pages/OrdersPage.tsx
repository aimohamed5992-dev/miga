import { ShoppingBag, Store } from 'lucide-react'
import { useSearchParams } from 'react-router-dom'
import { Badge } from '../components/ui/Badge'
import { Card } from '../components/ui/Card'
import { DataTable, type Column } from '../components/ui/DataTable'
import { EmptyState, Pagination, SearchInput, Tabs } from '../components/ui/ListControls'
import { fmt } from '../lib/format'
import { useMerchantOrders, useOrders } from '../lib/queries'
import { deliveryStatus, label, merchantOrderStatus, orderStatus, paymentStatus, type AdminMerchantOrder, type AdminOrder } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const PAGE_SIZE = 15

const status = (map: Parameters<typeof label>[0], v: number | null) => {
  if (v == null) return <span className="text-faint">—</span>
  const [t, tone] = label(map, v)
  return (
    <Badge tone={tone} dot>
      {t}
    </Badge>
  )
}

const number = (n: string) => (
  <span className="num font-bold whitespace-nowrap" dir="ltr">
    {n}
  </span>
)

const customerColumns: Column<AdminOrder>[] = [
  { head: 'رقم الطلب', cell: (o) => number(o.number) },
  {
    head: 'العميل',
    cell: (o) => (
      <div>
        <p className="font-bold whitespace-nowrap">{o.customerName}</p>
        <p className="num text-xs text-muted">{fmt.phone(o.customerPhone)}</p>
      </div>
    ),
  },
  {
    head: 'الحملة',
    className: 'max-w-60',
    cell: (o) => (
      <div className="min-w-0">
        <p className="truncate">{o.campaignTitle}</p>
        <p className="truncate text-xs text-muted">{o.storeName}</p>
      </div>
    ),
  },
  { head: 'الكمية', cell: (o) => <span className="num">{fmt.int(o.quantity)}</span> },
  { head: 'المبلغ', cell: (o) => <span className="num font-bold whitespace-nowrap">{fmt.money(o.totalAmount)}</span> },
  { head: 'الدفع', cell: (o) => status(paymentStatus, o.paymentStatus) },
  { head: 'التوصيل', cell: (o) => status(deliveryStatus, o.deliveryStatus) },
  {
    head: 'حالة الطلب',
    cell: (o) => (
      <div title={o.cancellationReason ?? undefined}>
        {status(orderStatus, o.status)}
        {o.cancellationReason && <p className="mt-1 max-w-40 truncate text-xs text-muted">{o.cancellationReason}</p>}
      </div>
    ),
  },
  { head: 'التاريخ', cell: (o) => <span className="text-xs whitespace-nowrap text-muted">{fmt.ago(o.createdAt)}</span> },
]

const merchantColumns: Column<AdminMerchantOrder>[] = [
  { head: 'رقم الطلب', cell: (o) => number(o.number) },
  {
    head: 'المتجر والحملة',
    className: 'max-w-64',
    cell: (o) => (
      <div className="min-w-0">
        <p className="truncate font-bold">{o.storeName}</p>
        <p className="truncate text-xs text-muted">{o.campaignTitle}</p>
      </div>
    ),
  },
  {
    head: 'الكمية',
    cell: (o) => (
      <div className="num">
        <p className="font-bold">{fmt.int(o.totalQuantity)}</p>
        <p className="text-xs text-muted">{fmt.int(o.customersCount)} عميل</p>
      </div>
    ),
  },
  { head: 'الإجمالي', cell: (o) => <span className="num font-bold whitespace-nowrap">{fmt.money(o.totalAmount)}</span> },
  { head: 'عمولة المنصة', cell: (o) => <span className="num whitespace-nowrap text-brand-700">{fmt.money(o.platformFee)}</span> },
  {
    head: 'التوصيل',
    cell: (o) => (
      <div className="w-28">
        <p className="num text-xs">
          <b>{fmt.int(o.delivered)}</b> / {fmt.int(o.deliveries)} تم توصيلها
        </p>
        <div className="mt-1 h-1.5 overflow-hidden rounded-full bg-black/[0.06]">
          <div className="h-full rounded-full bg-brand-600" style={{ width: `${o.deliveries ? (o.delivered / o.deliveries) * 100 : 0}%` }} />
        </div>
      </div>
    ),
  },
  { head: 'الحالة', cell: (o) => status(merchantOrderStatus, o.status) },
  { head: 'التاريخ', cell: (o) => <span className="text-xs whitespace-nowrap text-muted">{fmt.ago(o.createdAt)}</span> },
]

function CustomerOrders() {
  const { status: s, q, page, setStatus, setQuery, setPage } = useListParams('active')
  const { data, isLoading, isFetching, error } = useOrders(s, q, page, PAGE_SIZE)
  return (
    <>
      <div className="mb-5 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <Tabs
          value={s}
          onChange={setStatus}
          options={[
            { value: 'active', label: 'قيد التنفيذ' },
            { value: 'delivered', label: 'تم التوصيل' },
            { value: 'closed', label: 'ملغاة ومستردة' },
            { value: 'all', label: 'الكل' },
          ]}
        />
        <SearchInput value={q} onChange={setQuery} placeholder="رقم الطلب أو اسم العميل أو الجوال" />
      </div>
      <Card className="overflow-hidden">
        {error ? (
          <EmptyState image="admin_error_offline" title="تعذّر تحميل الطلبات" text={error.message} />
        ) : data?.items.length === 0 ? (
          <EmptyState image={q ? 'admin_empty_search' : 'admin_empty_list'} title={q ? 'لا توجد نتائج' : 'لا توجد طلبات هنا'} />
        ) : (
          <>
            <DataTable columns={customerColumns} rows={data?.items} loading={isLoading} fetching={isFetching} minWidth={1080} />
            {data && <Pagination page={page} pageSize={PAGE_SIZE} total={data.totalCount} onPage={setPage} />}
          </>
        )}
      </Card>
    </>
  )
}

function MerchantOrders() {
  const { status: s, q, page, setStatus, setQuery, setPage } = useListParams('open')
  const { data, isLoading, isFetching, error } = useMerchantOrders(s, q, page, PAGE_SIZE)
  return (
    <>
      <div className="mb-5 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <Tabs
          value={s}
          onChange={setStatus}
          options={[
            { value: 'open', label: 'مفتوحة' },
            { value: 'completed', label: 'مكتملة' },
            { value: 'all', label: 'الكل' },
          ]}
        />
        <SearchInput value={q} onChange={setQuery} placeholder="رقم الطلب أو المتجر أو الحملة" />
      </div>
      <Card className="overflow-hidden">
        {error ? (
          <EmptyState image="admin_error_offline" title="تعذّر تحميل الطلبات" text={error.message} />
        ) : data?.items.length === 0 ? (
          <EmptyState image={q ? 'admin_empty_search' : 'admin_empty_list'} title={q ? 'لا توجد نتائج' : 'لا توجد طلبات مجمّعة هنا'} />
        ) : (
          <>
            <DataTable columns={merchantColumns} rows={data?.items} loading={isLoading} fetching={isFetching} minWidth={1000} />
            {data && <Pagination page={page} pageSize={PAGE_SIZE} total={data.totalCount} onPage={setPage} />}
          </>
        )}
      </Card>
    </>
  )
}

/** Customer orders on campaigns, and the aggregated order each completed campaign produces for its merchant. */
export function OrdersPage() {
  const [params, setParams] = useSearchParams()
  const view = params.get('view') === 'merchant' ? 'merchant' : 'customer'
  const views = [
    { value: 'customer', label: 'طلبات العملاء', icon: ShoppingBag, hint: 'كل طلب عميل على حملة' },
    { value: 'merchant', label: 'الطلبات المجمّعة', icon: Store, hint: 'طلب واحد للتاجر عند اكتمال الحملة' },
  ] as const

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="mb-6 grid gap-3 sm:grid-cols-2 lg:max-w-2xl">
        {views.map(({ value, label: title, icon: Icon, hint }) => (
          <button
            key={value}
            onClick={() => setParams(value === 'customer' ? {} : { view: value }, { replace: true })}
            className={
              view === value
                ? 'flex items-center gap-3 rounded-2xl border-2 border-brand-600 bg-white p-4 text-start shadow-card'
                : 'flex items-center gap-3 rounded-2xl border-2 border-transparent bg-white/60 p-4 text-start hover:bg-white'
            }
          >
            <span className={view === value ? 'rounded-xl bg-brand-600 p-2.5 text-white' : 'rounded-xl bg-black/5 p-2.5 text-muted'}>
              <Icon className="size-5" />
            </span>
            <span>
              <span className="block font-extrabold">{title}</span>
              <span className="block text-xs text-muted">{hint}</span>
            </span>
          </button>
        ))}
      </div>
      {view === 'customer' ? <CustomerOrders key="c" /> : <MerchantOrders key="m" />}
    </div>
  )
}
