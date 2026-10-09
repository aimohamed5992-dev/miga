import clsx from 'clsx'
import { Check, ImagePlus, Link2Off, Megaphone, Package, Search, Store, Tags, Upload } from 'lucide-react'
import { useEffect, useRef, useState, type ReactNode } from 'react'
import { api, ApiError, imageUrl } from '../lib/api'
import { useAdminActions } from '../lib/queries'
import { useToast } from '../lib/toast'
import { bannerLinkLabel, type AdminBanner, type BannerInput, type BannerLinkType, type LinkTarget } from '../lib/types'
import { Button } from './ui/Button'
import { Drawer } from './ui/Drawer'
import { Field } from './ui/Field'
import { Spinner } from './ui/Spinner'

const linkIcons: Record<BannerLinkType, ReactNode> = {
  none: <Link2Off className="size-4" />,
  campaign: <Megaphone className="size-4" />,
  product: <Package className="size-4" />,
  store: <Store className="size-4" />,
  storeCategory: <Tags className="size-4" />,
}

/** Approximate look of the slide on the customer home screen. */
export function BannerPreview({ b, className }: { b: Pick<BannerInput, 'imageUrl' | 'titleAr' | 'subtitleAr' | 'buttonLabelAr'>; className?: string }) {
  const src = imageUrl(b.imageUrl)
  return (
    <div className={clsx('relative aspect-[16/7] overflow-hidden rounded-2xl bg-ink', className)}>
      {src ? (
        <img src={src} alt="" className="absolute inset-0 size-full object-cover" />
      ) : (
        <div className="absolute inset-0 flex items-center justify-center bg-gradient-to-br from-brand-50 to-white text-brand-300">
          <ImagePlus className="size-10" />
        </div>
      )}
      {(b.titleAr || b.subtitleAr || b.buttonLabelAr) && (
        <div className="absolute inset-0 flex flex-col justify-center bg-gradient-to-l from-ink/75 via-ink/35 to-transparent p-5 text-white">
          {b.titleAr && <p className="max-w-[70%] text-lg leading-tight font-extrabold sm:text-xl">{b.titleAr}</p>}
          {b.subtitleAr && <p className="mt-1 max-w-[65%] text-xs text-white/85 sm:text-sm">{b.subtitleAr}</p>}
          {b.buttonLabelAr && <span className="mt-3 w-fit rounded-full bg-brand-600 px-3.5 py-1.5 text-xs font-bold">{b.buttonLabelAr}</span>}
        </div>
      )}
    </div>
  )
}

interface Campaign {
  id: string
  titleAr: string
  storeName: string
  imageUrl: string | null
}
interface StoreRow {
  id: string
  nameAr: string
  categoryName: string | null
  logoUrl: string | null
}

/** Searches the public catalog for the item the banner opens. */
async function findTargets(type: BannerLinkType, q: string): Promise<LinkTarget[]> {
  if (type === 'storeCategory') {
    const cats = await api.get<{ id: string; nameAr: string; imageUrl: string | null }[]>('/api/store-categories')
    return cats.filter((c) => !q || c.nameAr.includes(q)).map((c) => ({ id: c.id, title: c.nameAr, sub: null, image: c.imageUrl }))
  }
  if (!q) {
    if (type === 'campaign') {
      const r = await api.get<{ items: Campaign[] }>('/api/campaigns', { pageSize: 30 })
      return r.items.map((c) => ({ id: c.id, title: c.titleAr, sub: c.storeName, image: c.imageUrl }))
    }
    if (type === 'store') {
      const r = await api.get<{ items: StoreRow[] }>('/api/stores', { pageSize: 30 })
      return r.items.map((s) => ({ id: s.id, title: s.nameAr, sub: s.categoryName, image: s.logoUrl }))
    }
    return []
  }
  const r = await api.get<{
    campaigns: Campaign[]
    products: { id: string; nameAr: string; mainImageUrl: string | null }[]
    stores: StoreRow[]
  }>('/api/search', { q })
  if (type === 'campaign') return r.campaigns.map((c) => ({ id: c.id, title: c.titleAr, sub: c.storeName, image: c.imageUrl }))
  if (type === 'product') return r.products.map((p) => ({ id: p.id, title: p.nameAr, sub: null, image: p.mainImageUrl }))
  return r.stores.map((s) => ({ id: s.id, title: s.nameAr, sub: s.categoryName, image: s.logoUrl }))
}

function TargetPicker({ type, selectedId, selectedTitle, onPick }: { type: BannerLinkType; selectedId: string | null; selectedTitle: string | null; onPick: (t: LinkTarget) => void }) {
  const [q, setQ] = useState('')
  const [rows, setRows] = useState<LinkTarget[] | null>(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    let live = true
    const t = setTimeout(async () => {
      setLoading(true)
      try {
        const r = await findTargets(type, q.trim())
        if (live) setRows(r)
      } catch {
        if (live) setRows([])
      } finally {
        if (live) setLoading(false)
      }
    }, 300)
    return () => {
      live = false
      clearTimeout(t)
    }
  }, [type, q])

  return (
    <div className="rounded-2xl border border-line bg-white">
      <label className="flex h-11 items-center gap-2 border-b border-line px-3.5">
        <Search className="size-4 text-faint" />
        <input
          value={q}
          onChange={(e) => setQ(e.target.value)}
          placeholder={type === 'product' ? 'اكتب اسم المنتج للبحث' : `ابحث عن ${bannerLinkLabel[type]}`}
          className="h-full flex-1 bg-transparent text-sm outline-none placeholder:text-faint"
        />
        {loading && <Spinner className="size-4 text-faint" />}
      </label>
      {selectedId && selectedTitle && (
        <p className="flex items-center gap-1.5 border-b border-line bg-brand-50 px-3.5 py-2 text-xs font-bold text-brand-700">
          <Check className="size-3.5" /> المختار: {selectedTitle}
        </p>
      )}
      <div className="max-h-56 overflow-y-auto p-1.5">
        {rows?.length === 0 && !loading && (
          <p className="p-4 text-center text-xs text-muted">{type === 'product' && !q ? 'اكتب للبحث عن منتج.' : 'لا توجد نتائج.'}</p>
        )}
        {rows?.map((r) => (
          <button
            key={r.id}
            type="button"
            onClick={() => onPick(r)}
            className={clsx('flex w-full items-center gap-3 rounded-xl p-2 text-start hover:bg-canvas', r.id === selectedId && 'bg-brand-50')}
          >
            <span className="size-9 shrink-0 overflow-hidden rounded-lg bg-canvas">{r.image && <img src={imageUrl(r.image)} alt="" className="size-full object-cover" />}</span>
            <span className="min-w-0 flex-1">
              <span className="block truncate text-sm font-bold">{r.title}</span>
              {r.sub && <span className="block truncate text-xs text-muted">{r.sub}</span>}
            </span>
            {r.id === selectedId && <Check className="size-4 text-brand-600" />}
          </button>
        ))}
      </div>
    </div>
  )
}

/** `datetime-local` value ↔ ISO (UTC). */
const toLocalInput = (iso: string | null) => {
  if (!iso) return ''
  const d = new Date(/(?:[zZ]|[+-]\d\d:\d\d)$/.test(iso) ? iso : `${iso}Z`)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}
const fromLocalInput = (v: string) => (v ? new Date(v).toISOString() : null)

const empty = (sortOrder: number): BannerInput => ({
  imageUrl: '',
  titleAr: '',
  subtitleAr: '',
  buttonLabelAr: 'تسوّق الآن',
  linkType: 'campaign',
  linkId: null,
  sortOrder,
  isActive: true,
  startsAt: null,
  endsAt: null,
})

/** Create / edit a home banner in a side sheet with a live preview. */
export function BannerEditor({ open, banner, nextOrder, onClose }: { open: boolean; banner: AdminBanner | null; nextOrder: number; onClose: () => void }) {
  const actions = useAdminActions()
  const toast = useToast()
  const [form, setForm] = useState<BannerInput>(() => empty(nextOrder))
  const [linkTitle, setLinkTitle] = useState<string | null>(null)
  const [uploading, setUploading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const fileRef = useRef<HTMLInputElement>(null)

  // Reset whenever the sheet opens for another banner.
  const [openedFor, setOpenedFor] = useState<string | null | undefined>(undefined)
  const key = open ? (banner?.id ?? 'new') : undefined
  if (key !== openedFor) {
    setOpenedFor(key)
    if (open) {
      setForm(banner ? { ...banner, titleAr: banner.titleAr ?? '', subtitleAr: banner.subtitleAr ?? '', buttonLabelAr: banner.buttonLabelAr ?? '' } : empty(nextOrder))
      setLinkTitle(banner?.linkTitle ?? null)
      setError(null)
    }
  }

  const set = <K extends keyof BannerInput>(k: K, v: BannerInput[K]) => setForm((f) => ({ ...f, [k]: v }))

  async function upload(file: File) {
    if (!/^image\/(jpeg|png|webp)$/.test(file.type)) return setError('الصورة يجب أن تكون JPG أو PNG أو WebP')
    if (file.size > 5 * 1024 * 1024) return setError('حجم الصورة أكبر من 5 ميجابايت')
    setUploading(true)
    setError(null)
    try {
      set('imageUrl', await api.upload('banners', file))
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'تعذّر رفع الصورة')
    } finally {
      setUploading(false)
    }
  }

  async function save() {
    if (!form.imageUrl) return setError('أضف صورة البانر')
    if (form.linkType !== 'none' && !form.linkId) return setError(`اختر ال${bannerLinkLabel[form.linkType]} الذي يفتحه البانر`)
    if (form.startsAt && form.endsAt && form.endsAt <= form.startsAt) return setError('تاريخ الانتهاء يجب أن يكون بعد البداية')
    setSaving(true)
    setError(null)
    try {
      const clean = (v: string | null) => (v && v.trim() ? v.trim() : null)
      await actions.saveBanner(banner?.id ?? null, {
        ...form,
        titleAr: clean(form.titleAr),
        subtitleAr: clean(form.subtitleAr),
        buttonLabelAr: clean(form.buttonLabelAr),
        linkId: form.linkType === 'none' ? null : form.linkId,
      })
      toast(banner ? 'تم حفظ البانر' : 'تمت إضافة البانر')
      onClose()
    } catch (e) {
      setError(e instanceof ApiError ? e.message : 'تعذّر الحفظ')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Drawer
      open={open}
      onClose={onClose}
      title={banner ? 'تعديل البانر' : 'بانر جديد'}
      footer={
        <>
          <Button loading={saving} disabled={uploading} onClick={save} icon={<Check className="size-4" />}>
            {banner ? 'حفظ التعديلات' : 'إضافة البانر'}
          </Button>
          <Button variant="secondary" onClick={onClose} disabled={saving}>
            إلغاء
          </Button>
          {error && <p className="w-full text-sm font-medium text-danger">{error}</p>}
        </>
      }
    >
      <div className="space-y-5">
        <div>
          <p className="mb-2 text-sm font-bold text-ink-3">المعاينة</p>
          <BannerPreview b={form} />
          <input
            ref={fileRef}
            type="file"
            accept="image/jpeg,image/png,image/webp"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0]
              if (f) upload(f)
              e.target.value = ''
            }}
          />
          <div className="mt-3 flex items-center gap-3">
            <Button variant="secondary" size="sm" loading={uploading} icon={<Upload className="size-4" />} onClick={() => fileRef.current?.click()}>
              {form.imageUrl ? 'تغيير الصورة' : 'رفع صورة'}
            </Button>
            <span className="text-xs text-muted">مقاس مقترح 1600×700، حتى 5 ميجابايت</span>
          </div>
        </div>

        <div className="grid gap-4">
          <Field label="العنوان" placeholder="مثال: اشترِ مع الجماعة" value={form.titleAr ?? ''} onChange={(e) => set('titleAr', e.target.value.slice(0, 120))} />
          <Field label="الوصف" placeholder="سطر قصير تحت العنوان" value={form.subtitleAr ?? ''} onChange={(e) => set('subtitleAr', e.target.value.slice(0, 200))} />
          <Field label="نص الزر" placeholder="تسوّق الآن" value={form.buttonLabelAr ?? ''} onChange={(e) => set('buttonLabelAr', e.target.value.slice(0, 40))} />
        </div>

        <div>
          <p className="mb-2 text-sm font-bold text-ink-3">عند الضغط يفتح</p>
          <div className="flex flex-wrap gap-2">
            {(Object.keys(bannerLinkLabel) as BannerLinkType[]).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => {
                  if (t === form.linkType) return
                  setForm((f) => ({ ...f, linkType: t, linkId: null }))
                  setLinkTitle(null)
                }}
                className={clsx(
                  'flex items-center gap-1.5 rounded-xl border px-3 py-2 text-sm font-bold transition-colors',
                  form.linkType === t ? 'border-brand-600 bg-brand-50 text-brand-700' : 'border-line bg-white text-ink-3 hover:border-brand-200',
                )}
              >
                {linkIcons[t]} {bannerLinkLabel[t]}
              </button>
            ))}
          </div>
          {form.linkType !== 'none' && (
            <div className="mt-3">
              <TargetPicker
                type={form.linkType}
                selectedId={form.linkId}
                selectedTitle={linkTitle}
                onPick={(t) => {
                  set('linkId', t.id)
                  setLinkTitle(t.title)
                }}
              />
            </div>
          )}
        </div>

        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="يبدأ العرض" type="datetime-local" value={toLocalInput(form.startsAt)} onChange={(e) => set('startsAt', fromLocalInput(e.target.value))} hint="فارغ = فورًا" />
          <Field label="ينتهي العرض" type="datetime-local" value={toLocalInput(form.endsAt)} onChange={(e) => set('endsAt', fromLocalInput(e.target.value))} hint="فارغ = بدون نهاية" />
        </div>

        <label className="flex cursor-pointer items-center justify-between rounded-2xl border border-line bg-white p-4">
          <span>
            <span className="block font-bold">ظاهر للعملاء</span>
            <span className="block text-xs text-muted">أوقفه مؤقتًا دون حذفه</span>
          </span>
          <input type="checkbox" checked={form.isActive} onChange={(e) => set('isActive', e.target.checked)} className="size-5 accent-brand-600" />
        </label>
      </div>
    </Drawer>
  )
}
