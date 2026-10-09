import { ArrowDown, ArrowUp, CalendarClock, Eye, EyeOff, Link2, Pencil, Plus, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { BannerEditor, BannerPreview } from '../components/BannerEditor'
import { Badge } from '../components/ui/Badge'
import { Button } from '../components/ui/Button'
import { Card } from '../components/ui/Card'
import { EmptyState, Skeleton } from '../components/ui/ListControls'
import { Modal } from '../components/ui/Modal'
import { ApiError } from '../lib/api'
import { fmt, toDate } from '../lib/format'
import { useAdminActions, useBanners } from '../lib/queries'
import { useToast } from '../lib/toast'
import { bannerLinkLabel, type AdminBanner, type BannerInput } from '../lib/types'

const input = (b: AdminBanner): BannerInput => ({
  imageUrl: b.imageUrl,
  titleAr: b.titleAr,
  subtitleAr: b.subtitleAr,
  buttonLabelAr: b.buttonLabelAr,
  linkType: b.linkType,
  linkId: b.linkId,
  sortOrder: b.sortOrder,
  isActive: b.isActive,
  startsAt: b.startsAt,
  endsAt: b.endsAt,
})

/** Shown to customers right now? (active and inside its date window) */
function liveState(b: AdminBanner, now: number): { text: string; tone: 'ok' | 'neutral' | 'warn' } {
  if (!b.isActive) return { text: 'متوقف', tone: 'neutral' }
  if (b.startsAt && toDate(b.startsAt).getTime() > now) return { text: `يبدأ ${fmt.date(b.startsAt)}`, tone: 'warn' }
  if (b.endsAt && toDate(b.endsAt).getTime() < now) return { text: 'انتهى عرضه', tone: 'neutral' }
  return { text: 'ظاهر الآن', tone: 'ok' }
}

export function BannersPage() {
  const { data, isLoading, error } = useBanners()
  const actions = useAdminActions()
  const toast = useToast()
  const [editing, setEditing] = useState<AdminBanner | 'new' | null>(null)
  const [deleting, setDeleting] = useState<AdminBanner | null>(null)
  const [busy, setBusy] = useState<string | null>(null)
  const [now] = useState(() => Date.now())

  const banners = data ?? []
  const nextOrder = banners.length ? Math.max(...banners.map((b) => b.sortOrder)) + 1 : 0

  async function run(id: string, fn: () => Promise<unknown>, done: string) {
    setBusy(id)
    try {
      await fn()
      toast(done)
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'تعذّر تنفيذ العملية', 'error')
    } finally {
      setBusy(null)
    }
  }

  /** Swap display order with the neighbour (renumbers both so ties can't stick). */
  function move(i: number, dir: -1 | 1) {
    const a = banners[i]
    const b = banners[i + dir]
    if (!a || !b) return
    run(
      a.id,
      async () => {
        await actions.saveBanner(a.id, { ...input(a), sortOrder: i + dir })
        await actions.saveBanner(b.id, { ...input(b), sortOrder: i })
      },
      'تم تغيير الترتيب',
    )
  }

  return (
    <div className="mx-auto max-w-[1400px]">
      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <p className="text-sm text-muted">
          الشرائح الإعلانية أعلى الصفحة الرئيسية في تطبيق العملاء، بالترتيب الظاهر هنا. كل شريحة تفتح حملة أو منتجًا أو متجرًا أو قسمًا.
        </p>
        <Button icon={<Plus className="size-4" />} onClick={() => setEditing('new')}>
          بانر جديد
        </Button>
      </div>

      {error ? (
        <Card>
          <EmptyState image="admin_error_offline" title="تعذّر تحميل البنرات" text={error.message} />
        </Card>
      ) : isLoading ? (
        <div className="grid gap-5 lg:grid-cols-2">
          {[0, 1].map((i) => (
            <Skeleton key={i} className="h-80" />
          ))}
        </div>
      ) : banners.length === 0 ? (
        <Card>
          <EmptyState
            image="admin_empty_banners"
            title="لا توجد بنرات"
            text="أضف أول شريحة إعلانية لتظهر في الصفحة الرئيسية للعملاء."
            action={
              <Button icon={<Plus className="size-4" />} onClick={() => setEditing('new')}>
                بانر جديد
              </Button>
            }
          />
        </Card>
      ) : (
        <div className="grid gap-5 lg:grid-cols-2">
          {banners.map((b, i) => {
            const state = liveState(b, now)
            return (
              <Card key={b.id} className={b.isActive ? 'p-4' : 'p-4 opacity-75'}>
                <div className="relative">
                  <BannerPreview b={b} />
                  <span className="num absolute start-3 top-3 flex size-8 items-center justify-center rounded-full bg-white/95 text-sm font-extrabold shadow-card">
                    {i + 1}
                  </span>
                </div>
                <div className="mt-4 flex flex-wrap items-center gap-2">
                  <Badge tone={state.tone} dot>
                    {state.text}
                  </Badge>
                  <Badge tone={b.linkType === 'none' ? 'neutral' : 'info'} icon={<Link2 className="size-3.5" />}>
                    {b.linkType === 'none' ? 'بدون رابط' : `${bannerLinkLabel[b.linkType]}: ${b.linkTitle ?? '—'}`}
                  </Badge>
                  {(b.startsAt || b.endsAt) && (
                    <Badge icon={<CalendarClock className="size-3.5" />}>
                      {b.startsAt ? fmt.date(b.startsAt) : 'الآن'} ← {b.endsAt ? fmt.date(b.endsAt) : 'مفتوح'}
                    </Badge>
                  )}
                </div>
                <div className="mt-4 flex flex-wrap items-center gap-2 border-t border-line pt-4">
                  <Button size="sm" variant="secondary" icon={<Pencil className="size-4" />} onClick={() => setEditing(b)}>
                    تعديل
                  </Button>
                  <Button
                    size="sm"
                    variant="secondary"
                    loading={busy === b.id}
                    icon={b.isActive ? <EyeOff className="size-4" /> : <Eye className="size-4" />}
                    onClick={() =>
                      run(b.id, () => actions.saveBanner(b.id, { ...input(b), isActive: !b.isActive }), b.isActive ? 'تم إيقاف البانر' : 'أصبح البانر ظاهرًا')
                    }
                  >
                    {b.isActive ? 'إيقاف' : 'إظهار'}
                  </Button>
                  <div className="ms-auto flex gap-1.5">
                    <button
                      disabled={i === 0 || !!busy}
                      onClick={() => move(i, -1)}
                      aria-label="تقديم"
                      title="تقديم"
                      className="flex size-9 items-center justify-center rounded-xl border border-line text-ink-3 hover:border-brand-300 hover:text-brand-600 disabled:opacity-30"
                    >
                      <ArrowUp className="size-4" />
                    </button>
                    <button
                      disabled={i === banners.length - 1 || !!busy}
                      onClick={() => move(i, 1)}
                      aria-label="تأخير"
                      title="تأخير"
                      className="flex size-9 items-center justify-center rounded-xl border border-line text-ink-3 hover:border-brand-300 hover:text-brand-600 disabled:opacity-30"
                    >
                      <ArrowDown className="size-4" />
                    </button>
                    <button
                      onClick={() => setDeleting(b)}
                      aria-label="حذف"
                      title="حذف"
                      className="flex size-9 items-center justify-center rounded-xl border border-line text-ink-3 hover:border-danger/40 hover:text-danger"
                    >
                      <Trash2 className="size-4" />
                    </button>
                  </div>
                </div>
              </Card>
            )
          })}
        </div>
      )}

      <BannerEditor open={editing !== null} banner={editing === 'new' ? null : editing} nextOrder={nextOrder} onClose={() => setEditing(null)} />

      <Modal
        open={!!deleting}
        onClose={() => setDeleting(null)}
        busy={busy === deleting?.id}
        tone="danger"
        icon={<Trash2 className="size-6" />}
        title="حذف البانر؟"
        footer={
          <>
            <Button variant="secondary" onClick={() => setDeleting(null)}>
              رجوع
            </Button>
            <Button
              variant="danger"
              loading={busy === deleting?.id}
              onClick={async () => {
                await run(deleting!.id, () => actions.deleteBanner(deleting!.id), 'تم حذف البانر')
                setDeleting(null)
              }}
            >
              حذف نهائي
            </Button>
          </>
        }
      >
        {deleting && <BannerPreview b={deleting} />}
        <p className="mt-3 text-sm text-muted">سيختفي من تطبيق العملاء فورًا. لإخفائه مؤقتًا استخدم «إيقاف» بدلًا من الحذف.</p>
      </Modal>
    </div>
  )
}
