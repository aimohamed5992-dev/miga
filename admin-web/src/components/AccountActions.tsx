import { BadgeCheck, Ban, RotateCcw, ShieldCheck, UserX } from 'lucide-react'
import { useState } from 'react'
import { ApiError } from '../lib/api'
import { useAdminActions } from '../lib/queries'
import { useToast } from '../lib/toast'
import { ReasonDialog } from './ReasonDialog'
import { Button } from './ui/Button'
import { Modal } from './ui/Modal'

const rejectSuggestions = {
  merchant: ['صورة السجل التجاري غير واضحة', 'رقم السجل التجاري غير صحيح', 'الرقم الضريبي غير مطابق', 'نشاط المتجر غير مسموح به على المنصة'],
  driver: ['رقم الهوية غير صحيح', 'رخصة القيادة منتهية أو غير واضحة', 'بيانات المركبة غير مكتملة', 'المدينة خارج نطاق الخدمة حاليًا'],
}
const suspendSuggestions = ['مخالفة شروط الاستخدام', 'شكاوى متكررة من العملاء', 'نشاط مشبوه على الحساب', 'بطلب من صاحب الحساب']

export interface AccountRef {
  id: string
  name: string
  kind: 'customer' | 'merchant' | 'driver'
  verification: string
  isActive: boolean
}

type Dialog = 'verify' | 'reject' | 'suspend' | 'reactivate' | null

/**
 * The buttons an admin can use on one account, with their dialogs:
 * verify / reject a merchant or driver registration, suspend with a reason, reactivate.
 */
export function AccountActions({ account, size = 'md', show = 'all' }: { account: AccountRef; size?: 'sm' | 'md'; show?: 'all' | 'review' }) {
  const actions = useAdminActions()
  const toast = useToast()
  const [dialog, setDialog] = useState<Dialog>(null)
  const [busy, setBusy] = useState(false)
  const { kind, name } = account
  const reviewable = kind !== 'customer' && (account.verification === 'pending' || account.verification === 'rejected')
  const who = kind === 'merchant' ? 'التاجر' : kind === 'driver' ? 'المندوب' : 'العميل'

  async function confirm(fn: () => Promise<unknown>, done: string) {
    setBusy(true)
    try {
      await fn()
      toast(done)
      setDialog(null)
    } catch (e) {
      toast(e instanceof ApiError ? e.message : 'تعذّر تنفيذ العملية', 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <>
      {reviewable && (
        <>
          <Button size={size} icon={<BadgeCheck className="size-4" />} onClick={() => setDialog('verify')}>
            {kind === 'merchant' ? 'توثيق التاجر' : 'تفعيل المندوب'}
          </Button>
          {account.verification === 'pending' && (
            <Button size={size} variant="secondary" icon={<Ban className="size-4" />} onClick={() => setDialog('reject')}>
              رفض
            </Button>
          )}
        </>
      )}
      {show === 'all' &&
        (account.isActive ? (
          <Button size={size} variant="secondary" className="hover:!border-danger/40 hover:!text-danger" icon={<UserX className="size-4" />} onClick={() => setDialog('suspend')}>
            إيقاف الحساب
          </Button>
        ) : (
          <Button size={size} variant="dark" icon={<RotateCcw className="size-4" />} onClick={() => setDialog('reactivate')}>
            إعادة التفعيل
          </Button>
        ))}

      <Modal
        open={dialog === 'verify'}
        onClose={() => setDialog(null)}
        busy={busy}
        tone="ok"
        icon={<ShieldCheck className="size-6" />}
        title={kind === 'merchant' ? `توثيق ${name}؟` : `تفعيل الكابتن ${name}؟`}
        footer={
          <>
            <Button variant="secondary" onClick={() => setDialog(null)} disabled={busy}>
              رجوع
            </Button>
            <Button
              loading={busy}
              onClick={() => kind !== 'customer' && confirm(() => actions.verify(kind, account.id), kind === 'merchant' ? 'تم توثيق التاجر' : 'تم تفعيل المندوب')}
            >
              {kind === 'merchant' ? 'توثيق' : 'تفعيل'}
            </Button>
          </>
        }
      >
        <p className="text-sm leading-7 text-muted">
          {kind === 'merchant'
            ? 'ستُفعَّل متاجره وتظهر للعملاء، ويستطيع إطلاق حملات الشراء الجماعي. سيصله إشعار بذلك.'
            : 'سيتمكن من الاتصال واستقبال طلبات التوصيل في مدينته. سيصله إشعار بذلك.'}
        </p>
      </Modal>

      <ReasonDialog
        open={dialog === 'reject'}
        onClose={() => setDialog(null)}
        icon={<Ban className="size-6" />}
        title={`رفض تسجيل ${who}`}
        description={`سيرى ${name} سبب الرفض في التطبيق ويمكنه تعديل بياناته وإعادة الإرسال.`}
        suggestions={kind === 'customer' ? [] : rejectSuggestions[kind]}
        confirmLabel="رفض التسجيل"
        onSubmit={async (reason) => {
          if (kind === 'customer') return
          await actions.reject(kind, account.id, reason)
          toast('تم رفض التسجيل وإبلاغ صاحبه بالسبب')
        }}
      />

      <ReasonDialog
        open={dialog === 'suspend'}
        onClose={() => setDialog(null)}
        icon={<UserX className="size-6" />}
        title={`إيقاف حساب ${name}`}
        description={
          <>
            سيُسجَّل خروجه من كل الأجهزة فورًا ولن يستطيع الدخول حتى تعيد تفعيله.
            {kind === 'merchant' && ' ستتوقف متاجره عن الظهور للعملاء.'}
            {kind === 'driver' && ' سيتوقف عن استقبال طلبات التوصيل.'}
          </>
        }
        suggestions={suspendSuggestions}
        confirmLabel="إيقاف الحساب"
        onSubmit={async (reason) => {
          await actions.setActive(account.id, false, reason)
          toast('تم إيقاف الحساب')
        }}
      />

      <Modal
        open={dialog === 'reactivate'}
        onClose={() => setDialog(null)}
        busy={busy}
        tone="ok"
        icon={<RotateCcw className="size-6" />}
        title={`إعادة تفعيل ${name}؟`}
        footer={
          <>
            <Button variant="secondary" onClick={() => setDialog(null)} disabled={busy}>
              رجوع
            </Button>
            <Button loading={busy} onClick={() => confirm(() => actions.setActive(account.id, true), 'تمت إعادة تفعيل الحساب')}>
              إعادة التفعيل
            </Button>
          </>
        }
      >
        <p className="text-sm leading-7 text-muted">
          سيتمكن من تسجيل الدخول واستخدام ميجا من جديد{kind === 'merchant' && '، وتعود متاجره الموثّقة للظهور'}. سيصله إشعار بذلك.
        </p>
      </Modal>
    </>
  )
}
