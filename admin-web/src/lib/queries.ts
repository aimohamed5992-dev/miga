import { keepPreviousData, useQuery, useQueryClient } from '@tanstack/react-query'
import { api } from './api'
import type {
  AdminCampaign,
  AdminDelivery,
  AdminBanner,
  AdminMap,
  AdminPayout,
  BannerInput,
  AdminMerchantOrder,
  AdminOrder,
  AdminUser,
  AdminUserDetail,
  Dashboard,
  Paged,
  PlatformSettings,
  SettingsInput,
  VerificationItem,
} from './types'

/** Platform numbers; also feeds the sidebar counters, so it refreshes every minute. */
export const useDashboard = () =>
  useQuery({
    queryKey: ['dashboard'],
    queryFn: () => api.get<Dashboard>('/api/admin/dashboard'),
    refetchInterval: 60_000,
  })

export const useRecentOrders = (count = 6) =>
  useQuery({
    queryKey: ['orders', 'recent', count],
    queryFn: () => api.get<Paged<AdminOrder>>('/api/admin/orders', { status: 'all', pageSize: count }),
    refetchInterval: 60_000,
  })

export type UserKind = 'customer' | 'merchant' | 'driver'

export const useVerifications = (type: 'all' | 'merchant' | 'driver', status: 'pending' | 'rejected' | 'verified') =>
  useQuery({
    queryKey: ['verifications', type, status],
    queryFn: () => api.get<VerificationItem[]>('/api/admin/verifications', { type, status }),
  })

export const useUsers = (type: UserKind, q: string, status: string, page: number, pageSize = 15) =>
  useQuery({
    queryKey: ['users', type, q, status, page, pageSize],
    queryFn: () => api.get<Paged<AdminUser>>('/api/admin/users', { type, q, status, page, pageSize }),
    placeholderData: keepPreviousData,
  })

export const useUser = (id: string | null) =>
  useQuery({
    queryKey: ['user', id],
    queryFn: () => api.get<AdminUserDetail>(`/api/admin/users/${id}`),
    enabled: !!id,
  })

/** Generic paged admin list (campaigns, orders, deliveries…) keyed by its path and filters. */
const usePaged = <T,>(path: string, status: string, q: string, page: number, pageSize: number) =>
  useQuery({
    queryKey: [path, status, q, page, pageSize],
    queryFn: () => api.get<Paged<T>>(path, { status, q, page, pageSize }),
    placeholderData: keepPreviousData,
    refetchInterval: 60_000,
  })

export const useCampaigns = (status: string, q: string, page: number, pageSize = 12) => usePaged<AdminCampaign>('/api/admin/campaigns', status, q, page, pageSize)
export const useOrders = (status: string, q: string, page: number, pageSize = 15) => usePaged<AdminOrder>('/api/admin/orders', status, q, page, pageSize)
export const useMerchantOrders = (status: string, q: string, page: number, pageSize = 15) =>
  usePaged<AdminMerchantOrder>('/api/admin/merchant-orders', status, q, page, pageSize)
export const useDeliveries = (status: string, q: string, page: number, pageSize = 15) => usePaged<AdminDelivery>('/api/admin/deliveries', status, q, page, pageSize)

export const usePayouts = (status: string, page: number, pageSize = 15) =>
  useQuery({
    queryKey: ['payouts', status, page, pageSize],
    queryFn: () => api.get<Paged<AdminPayout>>('/api/admin/payouts', { status, page, pageSize }),
    placeholderData: keepPreviousData,
    refetchInterval: 60_000,
  })

export const useBanners = () => useQuery({ queryKey: ['banners'], queryFn: () => api.get<AdminBanner[]>('/api/admin/banners') })

export const useSettings = () => useQuery({ queryKey: ['settings'], queryFn: () => api.get<PlatformSettings>('/api/admin/settings') })

/** Live map data; refreshes every 15 s. */
export const useMap = (cityId: string | null) =>
  useQuery({
    queryKey: ['map', cityId],
    queryFn: () => api.get<AdminMap>('/api/admin/map', { cityId }),
    refetchInterval: 15_000,
    placeholderData: keepPreviousData,
  })

/**
 * Admin write actions. Each refreshes the lists, counters and detail that depend on it.
 */
export function useAdminActions() {
  const qc = useQueryClient()
  const refresh = () => qc.invalidateQueries()
  const run = async (p: Promise<unknown>) => {
    await p
    await refresh()
  }
  return {
    verify: (kind: 'merchant' | 'driver', userId: string) => run(api.post(`/api/admin/${kind}s/${userId}/verify`)),
    reject: (kind: 'merchant' | 'driver', userId: string, reason: string) => run(api.post(`/api/admin/${kind}s/${userId}/reject`, { reason })),
    setActive: (userId: string, active: boolean, reason?: string) => run(api.patch(`/api/admin/users/${userId}/active`, { active, reason })),
    cancelCampaign: (id: string, reason: string) => run(api.post(`/api/admin/campaigns/${id}/cancel`, { reason })),
    retryDelivery: (id: string, note?: string) => run(api.post(`/api/admin/deliveries/${id}/retry`, { note: note || null })),
    refundDelivery: (id: string, reason: string) => run(api.post(`/api/admin/deliveries/${id}/refund`, { reason })),
    payoutPaid: (id: string, reference: string) => run(api.post(`/api/admin/payouts/${id}/paid`, { reference })),
    rejectPayout: (id: string, reason: string) => run(api.post(`/api/admin/payouts/${id}/reject`, { reason })),
    saveBanner: (id: string | null, input: BannerInput) =>
      run(id ? api.put<AdminBanner>(`/api/admin/banners/${id}`, input) : api.post<AdminBanner>('/api/admin/banners', input)),
    deleteBanner: (id: string) => run(api.del(`/api/admin/banners/${id}`)),
    saveSettings: (input: SettingsInput) => run(api.put<PlatformSettings>('/api/admin/settings', input)),
  }
}
