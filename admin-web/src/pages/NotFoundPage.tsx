import { Link } from 'react-router-dom'
import { Card } from '../components/ui/Card'
import { Illustration } from '../components/ui/Illustration'

export function NotFoundPage() {
  return (
    <Card className="mx-auto mt-6 flex max-w-xl flex-col items-center p-10 text-center">
      <Illustration name="admin_empty_search" className="size-44" />
      <h2 className="mt-6 text-2xl font-extrabold">الصفحة غير موجودة</h2>
      <Link to="/" className="mt-4 font-bold text-brand-600">
        العودة إلى لوحة المعلومات
      </Link>
    </Card>
  )
}
