import {
  BadgeCheck,
  Bike,
  Image,
  LayoutDashboard,
  type LucideIcon,
  Map,
  Megaphone,
  Settings,
  ShoppingBag,
  Store,
  Truck,
  Users,
  Wallet,
} from 'lucide-react'
import type { DashboardCounts } from '../lib/types'

export interface NavItem {
  to: string
  label: string
  icon: LucideIcon
  /** Count shown on the item (things waiting for the admin). */
  badge?: (c: DashboardCounts) => number
  /** Red badge = needs action; grey = informational. */
  urgent?: boolean
}

export interface NavGroup {
  title: string
  items: NavItem[]
}

export const nav: NavGroup[] = [
  {
    title: 'نظرة عامة',
    items: [
      { to: '/', label: 'لوحة المعلومات', icon: LayoutDashboard },
      { to: '/map', label: 'خريطة التوصيل', icon: Map, badge: (c) => c.deliveriesInProgress },
    ],
  },
  {
    title: 'الحسابات',
    items: [
      { to: '/verifications', label: 'طلبات التوثيق', icon: BadgeCheck, badge: (c) => c.merchantsPending + c.driversPending, urgent: true },
      { to: '/merchants', label: 'التجار', icon: Store },
      { to: '/drivers', label: 'المناديب', icon: Bike },
      { to: '/customers', label: 'العملاء', icon: Users },
    ],
  },
  {
    title: 'العمليات',
    items: [
      { to: '/campaigns', label: 'الحملات', icon: Megaphone },
      { to: '/orders', label: 'الطلبات', icon: ShoppingBag },
      { to: '/deliveries', label: 'التوصيلات', icon: Truck, badge: (c) => c.failedDeliveries, urgent: true },
    ],
  },
  {
    title: 'المالية والمحتوى',
    items: [
      { to: '/payouts', label: 'تحويلات التجار', icon: Wallet, badge: (c) => c.payoutsRequested, urgent: true },
      { to: '/banners', label: 'البنرات الإعلانية', icon: Image },
      { to: '/settings', label: 'الإعدادات', icon: Settings },
    ],
  },
]

export const allNavItems = nav.flatMap((g) => g.items)
