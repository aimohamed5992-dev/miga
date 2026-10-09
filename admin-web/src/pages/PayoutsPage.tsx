import { Ban, Banknote, Check, Copy, Landmark } from 'lucide-react'
import { useState } from 'react'
import { ReasonDialog } from '../components/ReasonDialog'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { DataTable, type Column } from '../components/ui/DataTable'
import { Field } from '../components/ui/Field'
import { Avatar, EmptyState, Pagination, Tabs } from '../components/ui/ListControls'
import { Modal } from '../components/ui/Modal'
import { ApiError } from '../lib/api'
import { fmt } from '../lib/format'
import { useAdminActions, useDashboard, usePayouts } from '../lib/queries'
import { useToast } from '../lib/toast'
import { label, payoutStatus, type AdminPayout } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const PAGE_SIZE = 15
const rejectSuggestions = ['الآيبان غير صحيح أو لا يطابق اسم المنشأة', 'الرصيد قيد المراجعة بسبب استرداد', 'بيانات الحساب البنكي ناقصة']

/** IBAN in groups of four, as printed on bank documents. */
const groupIban = (iban: string) => iban.replace(/\s/g, '').replace(/(.{4})/g, '$1 ').trim()

function CopyIban({ iban }: { iban: string }) {
  const toast = useToast()
  return (
    <button
      onClick={async (e) => {
        e.stopPropagation()
        try {
          await navigator.clipboard.writeText(iban.replace(/\s/g, ''))
          toast('تم نسخ الآيبان')
        } catch {
          toast('تعذّر النسخ، انسخه يدويًا', 'error')
        }
      }}
      className="group flex items-center gap-1.5 text-start"
      title="نسخ الآيبان"
    >
      <span className="num text-xs tracking-wide whitespace-nowrap text-ink-3" dir="ltr">
        {groupIban(iban)}
      </span>
      <Copy className="size-3.5 shrink-0 text-faint group-hover:text-brand-600" />
    </button>
  )
}

function PaidDialog({ payout, onClose }: { payout: AdminPayout | null; onClose: () => void }) {
  const actions = useAdminActions()
  const toast = useToast()
  const [reference, setReference] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const valid = reference.trim().length >= 3

  async function submit() {
    if (!valid) return
    setBusy(true)
    setError(null)
    try {
      await actions.payoutPaid(payout!.id, reference.trim())
      toast('تم تسجيل التحويل وإبلاغ التاجر')
      setReference('')
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'تعذّر تنفيذ العملية')
    } finally {
      setBusy(false)
    }
  }

  return (
    <Modal
      open={!!payout}
      onClose={onClose}
      busy={busy}
      tone="ok"
      icon={<Banknote className="size-6" />}
      title="تأكيد تحويل الأرباح"
      footer={
        <>
          <Button variant="secondary" onClick={onClose} disabled={busy}>
            رجوع
          </Button>
          <Button loading={busy} disabled={!valid} icon={<Check className="size-4" />} onClick={submit}>
            تم التحويل
          </Button>
        </>
      }
    >
      {payout && (
        <div className="mb-5 rounded-2xl bg-canvas p-4">
          <div className="flex items-baseline justify-between">
            <span className="text-sm text-muted">المبلغ</span>
            <span className="num text-2xl font-extrabold">{fmt.money(payout.amount)}</span>
          </div>
          <div className="mt-3 flex items-baseline justify-between gap-3 text-sm">
            <span className="text-muted">إلى</span>
            <span className="truncate font-bold">{payout.businessName || payout.merchantName}</span>
          </div>
          <div className="mt-2 flex items-center justify-between gap-3 text-sm">
            <span className="text-muted">{payout.bankName || 'البنك'}</span>
            <CopyIban iban={payout.iban} />
          </div>
        </div>
      )}
      <Field
        label="رقم مرجع التحويل البنكي"
        placeholder="مثال: TRX-2026-1008"
        value={reference}
        onChange={(e) => setReference(e.target.value.slice(0, 100))}
        dir="ltr"
        className="num"
        error={error}
        hint="بعد تنفيذ التحويل من البنك. يظهر المرجع للتاجر في التطبيق."
        autoFocus
      />
    </Modal>
  )
}

export function PayoutsPage() {
  const { status, page, setStatus, setPage } = useListParams('requested')
  const { data, isLoading, isFetching, error } = usePayouts(status, page, PAGE_SIZE)
  const counts = useDashboard().data?.counts
  const actions = useAdminActions()
  const toast = useToast()
  const [paying, setPaying] = useState<AdminPayout | null>(null)
  const [rejecting, setRejecting] = useState<AdminPayout | null>(null)

  const columns: Column<AdminPayout>[] = [
    {
      head: 'التاجر',
      cell: (p) => (
        <div className="flex items-center gap-3">
          <Avatar name={p.merchantName} />
          <div className="min-w-0">
            <p className="truncate font-bold">{p.businessName || p.merchantName}</p>
            <p className="truncate text-xs text-muted">{p.merchantName}</p>
          </div>
        </div>
      ),
    },
    {
      head: 'الحساب البنكي',
      cell: (p) => (
        <div>
          <p className="flex items-center gap-1.5 text-sm font-medium">
            <Landmark className="size-3.5 text-faint" /> {p.bankName || '—'}
          </p>
          <CopyIban iban={p.iban} />
        </div>
      ),
    },
    { head: 'المبلغ', cell: (p) => <span className="num text-base font-extrabold whitespace-nowrap">{fmt.money(p.amount)}</span> },
    {
      head: 'الحالة',
      cell: (p) => {
        const [t, tone] = label(payoutStatus, p.status)
        return (
          <div>
            <Badge tone={tone} dot>
              {t}
            </Badge>
            {p.transferReference && (
              <p className="num mt-1 text-xs text-muted" dir="ltr">
                {p.transferReference}
              </p>
            )}
            {p.rejectionReason && <p className="mt-1 max-w-48 truncate text-xs text-danger">{p.rejectionReason}</p>}
          </div>
        )
      },
    },
    {
      head: 'التاريخ',
      cell: (p) => (
        <div className="text-xs whitespace-nowrap text-muted">
          <p>طُلب {fmt.ago(p.createdAt)}</p>
          {p.paidAt && <p>حُوّل {fmt.date(p.paidAt)}</p>}
        </div>
      ),
    },
    {
      head: '',
      className: 'w-0',
      cell: (p) =>
        p.status === 1 && (
          <div className="flex justify-end gap-2">
            <Button size="sm" icon={<Check className="size-4" />} onClick={() => setPaying(p)}>
              تم التحويل
            </Button>
            <Button size="sm" variant="secondary" icon={<Ban className="size-4" />} onClick={() => setRejecting(p)}>
              رفض
            </Button>
          </div>
        ),
    },
  ]

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
        <div className="relative overflow-hidden rounded-card bg-gradient-to-l from-brand-600 to-brand-800 p-6 text-white shadow-brand">
          <img src="/brand/logo-white.png" alt="" className="pointer-events-none absolute -bottom-10 -left-8 size-44 opacity-10" />
          <div className="relative">
            <p className="text-sm text-white/80">بانتظار التحويل</p>
            <p className="num mt-1 text-3xl font-extrabold">{fmt.money(counts?.payoutsRequestedAmount ?? 0)}</p>
            <p className="mt-1 text-sm text-white/80">
              <span className="num">{fmt.int(counts?.payoutsRequested ?? 0)}</span> طلب
            </p>
          </div>
        </div>
        <Card className="p-6 xl:col-span-2">
          <p className="font-extrabold">كيف تتم المعالجة؟</p>
          <ol className="mt-2 list-inside list-decimal space-y-1 text-sm leading-6 text-muted">
            <li>انسخ الآيبان وحوّل المبلغ من حساب ميجا البنكي.</li>
            <li>اضغط «تم التحويل» واكتب رقم مرجع البنك، فيصل التاجر إشعار بالمرجع.</li>
            <li>عند وجود مشكلة اضغط «رفض» مع السبب، ويعود المبلغ إلى رصيد التاجر المتاح.</li>
          </ol>
        </Card>
      </div>

      <div className="mb-5">
        <Tabs
          value={status}
          onChange={setStatus}
          options={[
            { value: 'requested', label: 'بانتظار التحويل', count: counts?.payoutsRequested },
            { value: 'paid', label: 'تم تحويلها' },
            { value: 'rejected', label: 'مرفوضة' },
            { value: 'all', label: 'الكل' },
          ]}
        />
      </div>

      <Card className="overflow-hidden">
        {error ? (
          <EmptyState image="admin_error_offline" title="تعذّر تحميل الطلبات" text={error.message} />
        ) : data?.items.length === 0 ? (
          <EmptyState
            image="admin_empty_payouts"
            title={status === 'requested' ? 'لا توجد طلبات تحويل معلّقة' : 'لا توجد طلبات هنا'}
            text={status === 'requested' ? 'ستظهر هنا طلبات سحب الأرباح من التجار.' : undefined}
          />
        ) : (
          <>
            <DataTable columns={columns} rows={data?.items} loading={isLoading} fetching={isFetching} minWidth={980} />
            {data && <Pagination page={page} pageSize={PAGE_SIZE} total={data.totalCount} onPage={setPage} />}
          </>
        )}
      </Card>

      <PaidDialog payout={paying} onClose={() => setPaying(null)} />
      <ReasonDialog
        open={!!rejecting}
        onClose={() => setRejecting(null)}
        icon={<Ban className="size-6" />}
        title="رفض طلب التحويل"
        description={
          <>
            يعود <b className="num">{fmt.money(rejecting?.amount ?? 0)}</b> إلى رصيد {rejecting?.businessName || rejecting?.merchantName} المتاح، ويصله السبب.
          </>
        }
        suggestions={rejectSuggestions}
        confirmLabel="رفض الطلب"
        onSubmit={async (reason) => {
          await actions.rejectPayout(rejecting!.id, reason)
          toast('تم رفض الطلب وإعادة المبلغ لرصيد التاجر')
        }}
      />
    </div>
  )
}
