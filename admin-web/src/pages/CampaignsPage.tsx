import clsx from 'clsx'
import { Ban, Clock, Store, Users } from 'lucide-react'
import { useState } from 'react'
import { ReasonDialog } from '../components/ReasonDialog'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { EmptyState, Pagination, SearchInput, Skeleton, Tabs } from '../components/ui/ListControls'
import { imageUrl } from '../lib/api'
import { fmt } from '../lib/format'
import { useAdminActions, useCampaigns } from '../lib/queries'
import { useToast } from '../lib/toast'
import { campaignStatus, label, type AdminCampaign } from '../lib/types'
import { useListParams } from '../lib/useListParams'

const PAGE_SIZE = 12
const cancelSuggestions = ['مخالفة سياسة المنصة', 'سعر الحملة غير صحيح', 'المنتج غير متوفر لدى التاجر', 'بلاغات من العملاء عن المنتج']

function CampaignCard({ c, onCancel }: { c: AdminCampaign; onCancel: () => void }) {
  const [text, tone] = label(campaignStatus, c.status)
  const progress = Math.min(100, (c.currentQuantity / Math.max(1, c.targetQuantity)) * 100)
  const discount = c.originalPrice > 0 ? Math.round((1 - c.campaignPrice / c.originalPrice) * 100) : 0
  const live = c.status === 2
  const left = live ? fmt.left(c.endDate) : null
  const img = imageUrl(c.imageUrl)

  return (
    <Card className="flex h-full flex-col overflow-hidden">
      <div className="relative h-40 bg-canvas">
        {img ? <img src={img} alt="" className="size-full object-cover" /> : <div className="size-full bg-gradient-to-br from-brand-50 to-white" />}
        <div className="absolute inset-x-3 top-3 flex items-start justify-between">
          <Badge tone={tone} dot>
            {text}
          </Badge>
          {discount > 0 && <span className="num rounded-full bg-brand-600 px-2.5 py-1 text-xs font-extrabold text-white shadow-brand">-{discount}%</span>}
        </div>
      </div>
      <div className="flex flex-1 flex-col p-5">
        <p className="line-clamp-1 font-extrabold">{c.titleAr}</p>
        <p className="mt-1 flex items-center gap-1.5 truncate text-sm text-muted">
          <Store className="size-3.5 shrink-0" /> {c.storeName} · {c.merchantName}
        </p>

        <div className="mt-4 flex items-baseline gap-2">
          <span className="num text-xl font-extrabold text-brand-700">{fmt.money(c.campaignPrice)}</span>
          {discount > 0 && <span className="num text-sm text-faint line-through">{fmt.money(c.originalPrice)}</span>}
        </div>

        <div className="mt-4">
          <div className="flex justify-between text-xs">
            <span className="text-muted">التقدم</span>
            <span className="num font-bold">
              {fmt.int(c.currentQuantity)} / {fmt.int(c.targetQuantity)}
            </span>
          </div>
          <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-black/[0.06]">
            <div className={clsx('h-full rounded-full transition-all', c.status === 3 ? 'bg-brand-800' : 'bg-brand-600')} style={{ width: `${progress}%` }} />
          </div>
        </div>

        <div className="mt-4 flex items-center gap-4 text-xs text-muted">
          <span className="flex items-center gap-1">
            <Users className="size-3.5" /> <span className="num">{fmt.int(c.participants)}</span> مشترك
          </span>
          <span className="flex items-center gap-1">
            <Clock className="size-3.5" />
            {live ? (left ? `تنتهي خلال ${left}` : 'انتهى الوقت') : c.completedAt ? `اكتملت ${fmt.date(c.completedAt)}` : `حتى ${fmt.date(c.endDate)}`}
          </span>
        </div>

        {live && (
          <div className="mt-auto pt-4">
            <Button
              size="sm"
              variant="secondary"
              block
              className="hover:!border-danger/40 hover:!text-danger"
              icon={<Ban className="size-4" />}
              onClick={onCancel}
            >
              إلغاء الحملة
            </Button>
          </div>
        )}
      </div>
    </Card>
  )
}

export function CampaignsPage() {
  const { status, q, page, setStatus, setQuery, setPage } = useListParams('active')
  const { data, isLoading, isFetching, error } = useCampaigns(status, q, page, PAGE_SIZE)
  const actions = useAdminActions()
  const toast = useToast()
  const [cancelling, setCancelling] = useState<AdminCampaign | null>(null)

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="mb-6 flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <Tabs
          value={status}
          onChange={setStatus}
          options={[
            { value: 'active', label: 'نشطة' },
            { value: 'completed', label: 'مكتملة' },
            { value: 'ended', label: 'منتهية وملغاة' },
            { value: 'draft', label: 'مسودات' },
            { value: 'all', label: 'الكل' },
          ]}
        />
        <SearchInput value={q} onChange={setQuery} placeholder="ابحث بعنوان الحملة أو المتجر أو المنتج" />
      </div>

      {error ? (
        <Card>
          <EmptyState image="admin_error_offline" title="تعذّر تحميل الحملات" text={error.message} />
        </Card>
      ) : isLoading ? (
        <div className="grid gap-5 sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4">
          {Array.from({ length: 4 }, (_, i) => (
            <Skeleton key={i} className="h-96" />
          ))}
        </div>
      ) : data!.items.length === 0 ? (
        <Card>
          <EmptyState image={q ? 'admin_empty_search' : 'admin_empty_list'} title={q ? 'لا توجد نتائج' : 'لا توجد حملات هنا'} text={q ? `لا توجد حملة تطابق «${q}».` : undefined} />
        </Card>
      ) : (
        <>
          <div className={clsx('grid gap-5 transition-opacity sm:grid-cols-2 xl:grid-cols-3 2xl:grid-cols-4', isFetching && 'opacity-70')}>
            {data!.items.map((c) => (
              <CampaignCard key={c.id} c={c} onCancel={() => setCancelling(c)} />
            ))}
          </div>
          <Card className="mt-5">
            <Pagination page={page} pageSize={PAGE_SIZE} total={data!.totalCount} onPage={setPage} />
          </Card>
        </>
      )}

      <ReasonDialog
        open={!!cancelling}
        onClose={() => setCancelling(null)}
        icon={<Ban className="size-6" />}
        title={`إلغاء «${cancelling?.titleAr ?? ''}»`}
        description={
          <>
            سيُسترد المبلغ كاملًا لكل المشتركين (<b className="num">{fmt.int(cancelling?.participants ?? 0)}</b> عميل) ويصل التاجر إشعار بالسبب. لا يمكن التراجع
            عن الإلغاء.
          </>
        }
        suggestions={cancelSuggestions}
        confirmLabel="إلغاء الحملة واسترداد المبالغ"
        onSubmit={async (reason) => {
          await actions.cancelCampaign(cancelling!.id, reason)
          toast('تم إلغاء الحملة واسترداد المبالغ للعملاء')
        }}
      />
    </div>
  )
}
