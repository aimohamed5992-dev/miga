// Shapes returned by /api/admin/* (enums arrive as numbers) and their Arabic labels.

import type { Tone } from '../components/ui/Badge'

export interface Paged<T> {
  items: T[]
  page: number
  pageSize: number
  totalCount: number
  hasMore: boolean
}

export interface DashboardCounts {
  customers: number
  merchants: number
  merchantsPending: number
  drivers: number
  driversPending: number
  driversOnline: number
  suspendedUsers: number
  activeStores: number
  activeCampaigns: number
  campaignsCompleted30d: number
  ordersToday: number
  gmv30d: number
  commission30d: number
  deliveriesInProgress: number
  failedDeliveries: number
  payoutsRequested: number
  payoutsRequestedAmount: number
}

export interface DashboardDay {
  date: string
  gmv: number
  orders: number
}

export interface TopStore {
  storeId: string
  storeName: string
  gmv: number
  orders: number
}

export interface Dashboard {
  counts: DashboardCounts
  days: DashboardDay[]
  topStores: TopStore[]
}

export interface AdminOrder {
  id: string
  number: string
  customerName: string
  customerPhone: string
  campaignTitle: string
  storeName: string
  quantity: number
  totalAmount: number
  status: number
  paymentStatus: number | null
  deliveryStatus: number | null
  cancellationReason: string | null
  createdAt: string
}

type Label = readonly [string, Tone]

/** CampaignOrderStatus */
export const orderStatus: Record<number, Label> = {
  1: ['بانتظار الدفع', 'neutral'],
  2: ['مدفوع', 'info'],
  3: ['مؤكد', 'info'],
  4: ['قيد التجهيز', 'warn'],
  5: ['جاهز للتوصيل', 'warn'],
  6: ['في الطريق', 'info'],
  7: ['تم التوصيل', 'ok'],
  8: ['ملغي', 'danger'],
  9: ['مسترد', 'neutral'],
}

export const label = (map: Record<number, Label>, v: number | null | undefined): Label => (v != null && map[v]) || ['—', 'neutral']

export type Verification = 'verified' | 'pending' | 'rejected' | 'not_submitted'

export interface VerificationItem {
  userId: string
  type: 'merchant' | 'driver'
  fullName: string
  phone: string
  submittedAt: string
  status: 'pending' | 'rejected' | 'verified'
  rejectionReason: string | null
  reviewedAt: string | null
  businessNameAr: string | null
  commercialRegistrationNumber: string | null
  taxNumber: string | null
  storeName: string | null
  storeCategory: string | null
  nationalId: string | null
  city: string | null
  vehicleType: string | null
  vehicleModel: string | null
  plateNumber: string | null
  drivingLicenseNumber: string | null
}

export interface AdminUser {
  id: string
  fullName: string
  phone: string
  email: string | null
  userType: number
  isActive: boolean
  createdAt: string
  verification: Verification
  suspensionReason: string | null
  ordersCount: number
  totalSpent: number
  businessName: string | null
  storesCount: number
  city: string | null
  vehicleType: string | null
  deliveriesCount: number
  isAvailable: boolean
  rating: number | null
}

export interface AdminStoreRow {
  id: string
  nameAr: string
  status: number
  isVerified: boolean
  products: number
  campaigns: number
}

export interface AdminActivity {
  id: string
  number: string
  title: string
  amount: number
  /** Enum name (Delivered, Ready, …) — see activityStatus. */
  status: string
  date: string
}

export interface AdminUserDetail {
  user: AdminUser
  addresses: number
  bankName: string | null
  iban: string | null
  nationalId: string | null
  drivingLicenseNumber: string | null
  vehicleModel: string | null
  plateNumber: string | null
  rejectionReason: string | null
  stores: AdminStoreRow[]
  recent: AdminActivity[]
}

export const verificationLabel: Record<Verification, Label> = {
  verified: ['موثّق', 'ok'],
  pending: ['بانتظار المراجعة', 'warn'],
  rejected: ['مرفوض', 'danger'],
  not_submitted: ['لم يكمل التسجيل', 'neutral'],
}

/** StoreStatus */
export const storeStatus: Record<number, Label> = {
  1: ['نشط', 'ok'],
  2: ['غير نشط', 'neutral'],
  3: ['موقوف', 'danger'],
}

/** Status names used by the user activity list (customer orders, merchant orders, deliveries). */
export const activityStatus: Record<string, Label> = {
  Pending: ['قيد الانتظار', 'neutral'],
  Paid: ['مدفوع', 'info'],
  Confirmed: ['مؤكد', 'info'],
  SentToMerchant: ['أُرسل للتاجر', 'info'],
  Preparing: ['قيد التجهيز', 'warn'],
  ReadyForDelivery: ['جاهز للتوصيل', 'warn'],
  Ready: ['جاهز للاستلام', 'warn'],
  Assigned: ['مُسند', 'info'],
  DriverAccepted: ['قبلها المندوب', 'info'],
  PickedUp: ['تم الاستلام', 'info'],
  OutForDelivery: ['في الطريق', 'info'],
  Delivered: ['تم التوصيل', 'ok'],
  Completed: ['مكتمل', 'ok'],
  Failed: ['متعثر', 'danger'],
  Cancelled: ['ملغي', 'danger'],
  Refunded: ['مسترد', 'neutral'],
}

/** Driver vehicle types (same values as the driver app). */
export const vehicleLabel: Record<string, string> = {
  car: 'سيارة',
  van: 'فان',
  truck: 'شاحنة صغيرة',
  bike: 'دراجة نارية',
}

export interface AdminCampaign {
  id: string
  titleAr: string
  storeId: string
  storeName: string
  merchantName: string
  productName: string
  imageUrl: string | null
  originalPrice: number
  campaignPrice: number
  targetQuantity: number
  currentQuantity: number
  participants: number
  status: number
  startDate: string
  endDate: string
  completedAt: string | null
}

export interface AdminMerchantOrder {
  id: string
  number: string
  storeName: string
  campaignTitle: string
  totalQuantity: number
  customersCount: number
  totalAmount: number
  platformFee: number
  status: number
  deliveries: number
  delivered: number
  createdAt: string
  readyAt: string | null
  completedAt: string | null
}

export interface AdminDelivery {
  id: string
  number: string
  status: number
  driverName: string | null
  driverPhone: string | null
  customerName: string
  customerPhone: string
  storeName: string
  district: string
  city: string
  productName: string
  quantity: number
  fee: number
  orderAmount: number
  failureReason: string | null
  orderNumber: string
  createdAt: string
  acceptedAt: string | null
  deliveredAt: string | null
}

export interface MapPoint {
  lat: number
  lng: number
  approximate: boolean
}

export interface MapCity {
  id: string
  name: string
  lat: number
  lng: number
  deliveries: number
  driversOnline: number
}

export interface MapDriver {
  userId: string
  name: string
  phone: string
  city: string | null
  vehicleType: string | null
  isAvailable: boolean
  activeDeliveries: number
  position: MapPoint
  locationAt: string | null
}

export interface MapStore {
  id: string
  name: string
  city: string | null
  pickupAddress: string | null
  activeDeliveries: number
  position: MapPoint
}

export interface MapDelivery {
  id: string
  number: string
  status: number
  customerName: string
  customerPhone: string
  district: string
  city: string
  productName: string
  quantity: number
  storeId: string
  storeName: string
  driverUserId: string | null
  driverName: string | null
  failureReason: string | null
  createdAt: string
  acceptedAt: string | null
  destination: MapPoint
}

export interface AdminMap {
  cities: MapCity[]
  drivers: MapDriver[]
  stores: MapStore[]
  deliveries: MapDelivery[]
  generatedAt: string
}

/** CampaignStatus */
export const campaignStatus: Record<number, Label> = {
  1: ['مسودة', 'neutral'],
  2: ['نشطة', 'ok'],
  3: ['مكتملة', 'info'],
  4: ['لم تكتمل', 'danger'],
  5: ['ملغاة', 'danger'],
  6: ['قيد المعالجة', 'warn'],
  7: ['مغلقة', 'neutral'],
}

/** MerchantOrderStatus */
export const merchantOrderStatus: Record<number, Label> = {
  1: ['بانتظار الإرسال', 'neutral'],
  2: ['بانتظار تأكيد التاجر', 'info'],
  3: ['مؤكد', 'info'],
  4: ['قيد التجهيز', 'warn'],
  5: ['جاهز للاستلام', 'warn'],
  6: ['مكتمل', 'ok'],
  7: ['ملغي', 'danger'],
}

/** PaymentStatus */
export const paymentStatus: Record<number, Label> = {
  1: ['معلّق', 'neutral'],
  2: ['مدفوع', 'ok'],
  3: ['فشل الدفع', 'danger'],
  4: ['ملغي', 'neutral'],
  5: ['مسترد', 'info'],
  6: ['مسترد جزئيًا', 'info'],
}

/** DeliveryStatus */
export const deliveryStatus: Record<number, Label> = {
  1: ['بانتظار مندوب', 'neutral'],
  2: ['مُسندة', 'info'],
  3: ['قبلها المندوب', 'info'],
  4: ['استلمها المندوب', 'info'],
  5: ['في الطريق', 'info'],
  6: ['تم التوصيل', 'ok'],
  7: ['متعثرة', 'danger'],
  8: ['ملغاة', 'neutral'],
}

export interface AdminPayout {
  id: string
  merchantUserId: string
  merchantName: string
  businessName: string | null
  bankName: string | null
  iban: string
  amount: number
  status: number
  createdAt: string
  paidAt: string | null
  transferReference: string | null
  rejectionReason: string | null
}

/** PayoutStatus */
export const payoutStatus: Record<number, Label> = {
  1: ['بانتظار التحويل', 'warn'],
  2: ['تم التحويل', 'ok'],
  3: ['مرفوض', 'danger'],
}

export type BannerLinkType = 'none' | 'campaign' | 'product' | 'store' | 'storeCategory'

export interface AdminBanner {
  id: string
  imageUrl: string
  titleAr: string | null
  subtitleAr: string | null
  buttonLabelAr: string | null
  linkType: BannerLinkType
  linkId: string | null
  linkTitle: string | null
  sortOrder: number
  isActive: boolean
  startsAt: string | null
  endsAt: string | null
  createdAt: string
}

export type BannerInput = Omit<AdminBanner, 'id' | 'linkTitle' | 'createdAt'>

export const bannerLinkLabel: Record<BannerLinkType, string> = {
  none: 'بدون رابط',
  campaign: 'حملة',
  product: 'منتج',
  store: 'متجر',
  storeCategory: 'قسم متاجر',
}

export interface PlatformSettings {
  platformFeePercent: number
  deliveryFee: number
  support: { phone: string | null; whatsApp: string | null; email: string | null }
  updatedAt: string | null
  updatedBy: string | null
}

export interface SettingsInput {
  platformFeePercent: number
  deliveryFee: number
  supportPhone: string | null
  supportWhatsApp: string | null
  supportEmail: string | null
}

/** One pickable banner target from the public catalog. */
export interface LinkTarget {
  id: string
  title: string
  sub: string | null
  image: string | null
}
