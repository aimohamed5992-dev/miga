import { AlertTriangle, Bike, MapPinned, RotateCcw, Undo2 } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { ReasonDialog } from '../components/ReasonDialog'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { DataTable, type Column } from '../components/ui/DataTable'
import { EmptyState, Pagination, SearchInput, Tabs } from '../components/ui/ListControls'
import { Modal } from '../components/ui/Modal'
import { ApiError } from '../lib/api'
import { fmt } from '../lib/format'
import { useAdminActions, useDashboard, useDeliveries } from '../lib/queries'
import { useToast } from '../lib/toast'
import { deliveryStatus, label, type AdminDelivery } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const PAGE_SIZE = 15
const refundSuggestions = ['تعذّر الوصول إلى العميل بعد عدة محاولات', 'العميل رفض استلام الطلب', 'العنوان غير صحيح أو خارج النطاق', 'تلف المنتج أثناء التوصيل']

function RetryDialog({ delivery, onClose }: { delivery: AdminDelivery | null; onClose: () => void }) {
  const actions = useAdminActions()
  const toast = useToast()
  const [note, setNote] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    setBusy(true)
    setError(null)
    try {
      await actions.retryDelivery(delivery!.id, note.trim())
      toast('أُعيدت التوصيلة للمندوب وتم إبلاغ العميل')
      setNote('')
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'تعذّر تنفيذ العملية')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      open={!!delivery}
      onClose={onClose}
      busy={busy}
      icon={<RotateCcw className="size-6" />}
      title={`إعادة محاولة ${delivery?.number ?? ''}`}
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            رجوع
          </Button>
          <Button loading={busy} onClick={submit}>
            إعادة المحاولة
          </Button>
        </>
      }
    >
      <p className="text-sm leading-7 text-muted">
        تعود التوصيلة إلى المندوب <b className="text-ink">{delivery?.driverName}</b> (الطلب ما زال معه) ليبدأ الرحلة من جديد، ويصل العميل إشعار بذلك. استخدمها بعد
        التواصل مع العميل.
      </p>
      <textarea
        value={note}
        onChange={(e) => setNote(e.target.value.slice(0, 300))}
        rows={2}
        placeholder="ملاحظة للمندوب (اختياري) — مثال: العميل متاح بعد المغرب"
        className="mt-4 w-full resize-none rounded-2xl border border-line p-3.5 text-[15px] outline-none placeholder:text-faint focus:border-brand-400 focus:ring-4 focus:ring-brand-100"
      />
      {error && <p className="mt-1 text-xs text-danger">{error}</p>}
    </Modal>
  )
}

export function DeliveriesPage() {
  const { status, q, page, setStatus, setQuery, setPage } = useListParams('failed')
  const { data, isLoading, isFetching, error } = useDeliveries(status, q, page, PAGE_SIZE)
  const counts = useDashboard().data?.counts
  const actions = useAdminActions()
  const toast = useToast()
  const [retrying, setRetrying] = useState<AdminDelivery | null>(null)
  const [refunding, setRefunding] = useState<AdminDelivery | null>(null)

  const columns: Column<AdminDelivery>[] = [
    {
      head: 'التوصيلة',
      cell: (d) => (
        <div className="num whitespace-nowrap" dir="ltr">
          <p className="text-end font-bold">{d.number}</p>
          <p className="text-end text-xs text-muted">{d.orderNumber}</p>
        </div>
      ),
    },
    {
      head: 'العميل والعنوان',
      cell: (d) => (
        <div>
          <p className="font-bold whitespace-nowrap">{d.customerName}</p>
          <p className="text-xs whitespace-nowrap text-muted">
            {d.district}، {d.city} · <span className="num">{fmt.phone(d.customerPhone)}</span>
          </p>
        </div>
      ),
    },
    {
      head: 'المنتج',
      className: 'max-w-44',
      cell: (d) => (
        <div className="min-w-0">
          <p className="truncate">
            {d.productName} <span className="num text-muted">×{d.quantity}</span>
          </p>
          <p className="truncate text-xs text-muted">{d.storeName}</p>
        </div>
      ),
    },
    {
      head: 'المندوب',
      cell: (d) =>
        d.driverName ? (
          <div>
            <p className="flex items-center gap-1.5 font-bold whitespace-nowrap">
              <Bike className="size-3.5 text-faint" /> {d.driverName}
            </p>
            {d.driverPhone && <p className="num text-xs text-muted">{fmt.phone(d.driverPhone)}</p>}
          </div>
        ) : (
          <span className="text-xs text-faint">لم يُسند بعد</span>
        ),
    },
    {
      head: 'الحالة',
      cell: (d) => {
        const [t, tone] = label(deliveryStatus, d.status)
        return (
          <div>
            <Badge tone={tone} dot>
              {t}
            </Badge>
            {d.failureReason && (
              <p className="mt-1 flex max-w-48 items-center gap-1 text-xs text-danger" title={d.failureReason}>
                <AlertTriangle className="size-3 shrink-0" /> <span className="truncate">{d.failureReason}</span>
              </p>
            )}
            <p className="mt-1 text-xs whitespace-nowrap text-muted">{d.deliveredAt ? `وصلت ${fmt.ago(d.deliveredAt)}` : fmt.ago(d.createdAt)}</p>
          </div>
        )
      },
    },
    {
      head: '',
      className: 'w-0',
      cell: (d) => (
        <div className="flex items-center justify-end gap-2">
          {d.status === 7 && (
            <>
              <Button size="sm" icon={<RotateCcw className="size-4" />} onClick={() => setRetrying(d)}>
                إعادة المحاولة
              </Button>
              <Button size="sm" variant="secondary" icon={<Undo2 className="size-4" />} onClick={() => setRefunding(d)}>
                استرداد
              </Button>
            </>
          )}
          {d.status !== 6 && d.status !== 8 && (
            <Link
              to={`/map?delivery=${d.id}`}
              title="عرض على الخريطة"
              aria-label="عرض على الخريطة"
              className="flex size-9 items-center justify-center rounded-xl border border-line bg-white text-ink-3 hover:border-brand-300 hover:text-brand-600"
            >
              <MapPinned className="size-4" />
            </Link>
          )}
        </div>
      ),
    },
  ]

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="mb-6 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <Tabs
          value={status}
          onChange={setStatus}
          options={[
            { value: 'failed', label: 'متعثرة', count: counts?.failedDeliveries },
            { value: 'in_progress', label: 'جارية', count: counts?.deliveriesInProgress },
            { value: 'waiting', label: 'بانتظار مندوب' },
            { value: 'delivered', label: 'تم توصيلها' },
            { value: 'all', label: 'الكل' },
          ]}
        />
        <SearchInput value={q} onChange={setQuery} placeholder="رقم التوصيلة أو الطلب أو العميل أو المندوب" />
      </div>

      {status === 'failed' && (
        <p className="mb-5 text-sm text-muted">
          تواصل مع العميل ثم اختر: <b>إعادة المحاولة</b> مع نفس المندوب، أو <b>استرداد</b> المبلغ للعميل وإغلاق التوصيلة.
        </p>
      )}

      <Card className="overflow-hidden">
        {error ? (
          <EmptyState image="admin_error_offline" title="تعذّر تحميل التوصيلات" text={error.message} />
        ) : data?.items.length === 0 ? (
          <EmptyState
            image={q ? 'admin_empty_search' : 'admin_empty_deliveries'}
            title={q ? 'لا توجد نتائج' : status === 'failed' ? 'لا توجد توصيلات متعثرة' : 'لا توجد توصيلات هنا'}
            text={status === 'failed' && !q ? 'كل التوصيلات تسير كما يجب.' : undefined}
          />
        ) : (
          <>
            <DataTable columns={columns} rows={data?.items} loading={isLoading} fetching={isFetching} minWidth={980} />
            {data && <Pagination page={page} pageSize={PAGE_SIZE} total={data.totalCount} onPage={setPage} />}
          </>
        )}
      </Card>

      <RetryDialog delivery={retrying} onClose={() => setRetrying(null)} />
      <ReasonDialog
        open={!!refunding}
        onClose={() => setRefunding(null)}
        icon={<Undo2 className="size-6" />}
        title={`استرداد ${refunding?.number ?? ''}`}
        description={
          <>
            يُسترد <b className="num">{fmt.money(refunding?.orderAmount ?? 0)}</b> للعميل {refunding?.customerName} وتُغلق التوصيلة، ويُسوّى الباقي للتاجر. لا يمكن التراجع.
          </>
        }
        suggestions={refundSuggestions}
        confirmLabel="استرداد المبلغ"
        onSubmit={async (reason) => {
          await actions.refundDelivery(refunding!.id, reason)
          toast('تم استرداد المبلغ للعميل')
        }}
      />
    </div>
  )
}
