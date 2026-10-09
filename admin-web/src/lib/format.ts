// Arabic-friendly formatting shared by the dashboard (Western digits, as in the apps).

const money = new Intl.NumberFormat('en-US', { maximumFractionDigits: 2 })
const int = new Intl.NumberFormat('en-US')

/** API times are UTC; values read back from the database come without a zone suffix, so add it before parsing. */
export const toDate = (v: string | Date) => (typeof v === 'string' ? new Date(/(?:[zZ]|[+-]\d\d:\d\d)$/.test(v) ? v : `${v}Z`) : v)

export const fmt = {
  money: (v: number) => `${money.format(v)} ر.س`,
  int: (v: number) => int.format(v),
  /** 0533333333 from +966533333333 */
  phone: (e164: string) => (e164.startsWith('+966') ? `0${e164.slice(4)}` : e164),
  date: (iso: string | Date) => {
    const d = toDate(iso)
    return `${d.getDate()}/${d.getMonth() + 1}/${d.getFullYear()}`
  },
  ago: (iso: string | Date) => {
    const d = toDate(iso)
    const m = Math.round((Date.now() - d.getTime()) / 60000)
    if (m < 1) return 'الآن'
    if (m < 60) return `منذ ${m} د`
    const h = Math.round(m / 60)
    if (h < 24) return `منذ ${h} س`
    return `منذ ${Math.round(h / 24)} يوم`
  },
  /** Time until a future date: "3 أيام" / "5 س" / "20 د"; null when it has passed. */
  left: (iso: string | Date) => {
    const m = Math.round((toDate(iso).getTime() - Date.now()) / 60000)
    if (m <= 0) return null
    if (m < 60) return `${m} د`
    const h = Math.round(m / 60)
    if (h < 48) return `${h} س`
    return `${Math.round(h / 24)} يوم`
  },
}
