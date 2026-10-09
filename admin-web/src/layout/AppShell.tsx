import clsx from 'clsx'
import { ChevronDown, LogOut, Menu, RefreshCw, X } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { useIsFetching, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../auth/authState'
import { Logo } from '../components/ui/Logo'
import { fmt } from '../lib/format'
import { useDashboard } from '../lib/queries'
import { allNavItems, nav } from './nav'

function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  const { data } = useDashboard()
  const counts = data?.counts
  return (
    <div className="relative flex h-full flex-col bg-gradient-to-b from-brand-600 to-brand-800 text-white">
      <div
        className="pointer-events-none absolute inset-x-0 top-0 h-72"
        style={{ background: 'radial-gradient(420px 240px at 85% -15%, rgba(255,255,255,.18), transparent 70%)' }}
      />
      <div className="relative px-6 pt-7 pb-6">
        <Logo light size={38} />
      </div>
      <nav className="relative flex-1 space-y-6 overflow-y-auto px-3.5 pb-6">
        {nav.map((group) => (
          <div key={group.title}>
            <p className="mb-2 px-3 text-[11px] font-bold tracking-wide text-white/55">{group.title}</p>
            <ul className="space-y-0.5">
              {group.items.map(({ to, label, icon: Icon, badge, urgent }) => {
                const n = counts && badge ? badge(counts) : 0
                return (
                  <li key={to}>
                    <NavLink
                      to={to}
                      end={to === '/'}
                      onClick={onNavigate}
                      className={({ isActive }) =>
                        clsx(
                          'group relative flex h-11 items-center gap-3 rounded-xl px-3 text-[15px] font-medium transition-colors',
                          isActive ? 'bg-white text-brand-700 shadow-[0_8px_20px_-10px_rgb(0_0_0/.45)]' : 'text-white/80 hover:bg-white/10 hover:text-white',
                        )
                      }
                    >
                      {({ isActive }) => (
                        <>
                          <Icon className={clsx('size-[19px] shrink-0', isActive ? 'text-brand-600' : 'text-white/60 group-hover:text-white')} />
                          <span className="flex-1 truncate">{label}</span>
                          {n > 0 && (
                            <span
                              className={clsx(
                                'num min-w-6 rounded-full px-1.5 py-0.5 text-center text-xs font-bold',
                                urgent ? (isActive ? 'bg-brand-600 text-white' : 'bg-white text-brand-700') : isActive ? 'bg-brand-50 text-brand-700' : 'bg-white/15 text-white',
                              )}
                            >
                              {fmt.int(n)}
                            </span>
                          )}
                        </>
                      )}
                    </NavLink>
                  </li>
                )
              })}
            </ul>
          </div>
        ))}
      </nav>
      <div className="relative border-t border-white/15 px-6 py-4 text-xs text-white/60">منصة ميجا للشراء الجماعي</div>
    </div>
  )
}

function AccountMenu() {
  const { account, signOut } = useAuth()
  const [open, setOpen] = useState(false)
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!open) return
    const close = (e: MouseEvent) => !ref.current?.contains(e.target as Node) && setOpen(false)
    document.addEventListener('mousedown', close)
    return () => document.removeEventListener('mousedown', close)
  }, [open])

  const name = account?.fullName || 'مدير ميجا'
  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen((o) => !o)}
        className="flex items-center gap-2.5 rounded-2xl py-1.5 ps-1.5 pe-3 transition-colors hover:bg-black/5"
        aria-expanded={open}
      >
        <span className="flex size-9 items-center justify-center rounded-xl bg-brand-600 text-sm font-extrabold text-white">{name.trim()[0]}</span>
        <span className="hidden text-start sm:block">
          <span className="block text-sm leading-tight font-bold">{name}</span>
          <span className="block text-xs text-muted">مدير النظام</span>
        </span>
        <ChevronDown className={clsx('size-4 text-faint transition-transform', open && 'rotate-180')} />
      </button>
      {open && (
        <div className="animate-fade-up absolute end-0 top-full z-30 mt-2 w-60 rounded-2xl border border-line bg-white p-2 shadow-pop">
          <div className="border-b border-line px-3 pt-2 pb-3">
            <p className="font-bold">{name}</p>
            <p className="num text-sm text-muted" dir="ltr">
              {account && fmt.phone(account.phoneNumber)}
            </p>
          </div>
          <button
            onClick={signOut}
            className="mt-1 flex w-full items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm font-bold text-danger hover:bg-danger-soft"
          >
            <LogOut className="size-4" /> تسجيل الخروج
          </button>
        </div>
      )}
    </div>
  )
}

/** Re-fetches every query on the page; spins while anything is loading. */
function RefreshButton() {
  const qc = useQueryClient()
  const fetching = useIsFetching() > 0
  return (
    <button
      onClick={() => qc.invalidateQueries()}
      title="تحديث البيانات"
      aria-label="تحديث البيانات"
      className="flex size-10 items-center justify-center rounded-xl border border-line bg-white text-ink-3 transition-colors hover:border-brand-300 hover:text-brand-600"
    >
      <RefreshCw className={clsx('size-[18px]', fetching && 'animate-spin')} />
    </button>
  )
}

export function AppShell() {
  const [drawer, setDrawer] = useState(false)
  const { pathname } = useLocation()
  const current = allNavItems.find((i) => (i.to === '/' ? pathname === '/' : pathname.startsWith(i.to)))

  useEffect(() => {
    document.title = current ? `${current.label} — ميجا` : 'ميجا — لوحة الإدارة'
  }, [current])

  return (
    <div className="flex min-h-full">
      {/* Desktop sidebar (right side in RTL) */}
      <aside className="sticky top-0 hidden h-screen w-72 shrink-0 overflow-hidden lg:block">
        <Sidebar />
      </aside>

      {/* Mobile drawer */}
      {drawer && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-ink/50 backdrop-blur-sm" onClick={() => setDrawer(false)} />
          <aside className="animate-fade-up absolute inset-y-0 start-0 w-72 overflow-hidden shadow-pop">
            <Sidebar onNavigate={() => setDrawer(false)} />
            <button
              onClick={() => setDrawer(false)}
              aria-label="إغلاق القائمة"
              className="absolute end-3 top-6 flex size-9 items-center justify-center rounded-xl text-white/70 hover:bg-white/10"
            >
              <X className="size-5" />
            </button>
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-20 flex h-18 items-center gap-3 border-b border-line/70 bg-canvas/85 px-4 backdrop-blur-md sm:px-8">
          <button
            onClick={() => setDrawer(true)}
            aria-label="فتح القائمة"
            className="flex size-10 items-center justify-center rounded-xl border border-line bg-white lg:hidden"
          >
            <Menu className="size-5" />
          </button>
          <h1 className="flex-1 truncate text-lg font-extrabold sm:text-xl">{current?.label ?? 'ميجا'}</h1>
          <RefreshButton />
          <AccountMenu />
        </header>
        <main className="flex-1 px-4 py-6 sm:px-8 sm:py-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
