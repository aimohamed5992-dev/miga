// MIGA API client for the admin dashboard: JSON in/out, bearer token, one shared refresh on 401,
// Arabic error messages (the API returns ProblemDetails with an Arabic `title` and a stable `code`).

const BASE = (import.meta.env.VITE_API_URL as string | undefined)?.replace(/\/$/, '') ?? ''

const ACCESS_KEY = 'miga.admin.access'
const REFRESH_KEY = 'miga.admin.refresh'

export class ApiError extends Error {
  readonly status: number
  readonly code: string

  constructor(status: number, code: string, message: string) {
    super(message)
    this.status = status
    this.code = code
  }

  get isNetwork() {
    return this.status === 0
  }
}

export interface Account {
  id: string
  fullName: string
  phoneNumber: string
  email: string | null
  userType: number
  verificationStatus: string
}

interface AuthResponse {
  accessToken: string
  refreshToken: string
  account: Account
}

export interface OtpSent {
  phone: string
  expiresInSeconds: number
  resendAfterSeconds: number
  devCode: string | null
}

export type Query = Record<string, string | number | boolean | null | undefined>

/** Called when the session can't be refreshed (the app sends the admin back to the login page). */
let onSessionExpired: () => void = () => {}
export const setSessionExpiredHandler = (fn: () => void) => {
  onSessionExpired = fn
}

const tokens = {
  get access() {
    return safe(() => localStorage.getItem(ACCESS_KEY))
  },
  get refresh() {
    return safe(() => localStorage.getItem(REFRESH_KEY))
  },
  save(a: AuthResponse) {
    safe(() => {
      localStorage.setItem(ACCESS_KEY, a.accessToken)
      localStorage.setItem(REFRESH_KEY, a.refreshToken)
    })
  },
  clear() {
    safe(() => {
      localStorage.removeItem(ACCESS_KEY)
      localStorage.removeItem(REFRESH_KEY)
    })
  },
}

function safe<T>(fn: () => T): T | null {
  try {
    return fn()
  } catch {
    return null
  }
}

export const hasSession = () => !!tokens.refresh

function url(path: string, query?: Query) {
  const u = new URL(BASE + path, window.location.origin)
  for (const [k, v] of Object.entries(query ?? {})) if (v !== null && v !== undefined && v !== '') u.searchParams.set(k, String(v))
  return BASE ? u.toString() : u.pathname + u.search
}

async function toError(res: Response): Promise<ApiError> {
  let code = 'error'
  let message = 'حدث خطأ غير متوقع، حاول مرة أخرى'
  try {
    const body = await res.json()
    code = body.code ?? code
    message = body.title ?? message
    // Validation errors: show the first field message.
    if (body.errors && typeof body.errors === 'object') {
      const first = Object.values(body.errors as Record<string, string[]>)[0]?.[0]
      if (first) message = first
    }
  } catch {
    /* not JSON */
  }
  if (res.status === 403 && code === 'error') message = 'ليست لديك صلاحية لهذه العملية'
  if (res.status === 429 && code === 'error') message = 'محاولات كثيرة، انتظر قليلًا ثم أعد المحاولة'
  return new ApiError(res.status, code, message)
}

let refreshing: Promise<boolean> | null = null

/** Single-flight refresh: concurrent 401s wait for one refresh call. */
function refresh(): Promise<boolean> {
  refreshing ??= (async () => {
    const token = tokens.refresh
    if (!token) return false
    try {
      const res = await fetch(url('/api/auth/refresh'), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refreshToken: token }),
      })
      if (!res.ok) return false
      tokens.save(await res.json())
      return true
    } catch {
      return false
    } finally {
      setTimeout(() => (refreshing = null), 0)
    }
  })()
  return refreshing
}

async function send<T>(method: string, path: string, body?: unknown, query?: Query, retried = false): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  const isForm = body instanceof FormData
  if (body !== undefined && !isForm) headers['Content-Type'] = 'application/json'
  const access = tokens.access
  if (access) headers.Authorization = `Bearer ${access}`

  let res: Response
  try {
    res = await fetch(url(path, query), {
      method,
      headers,
      body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
    })
  } catch {
    throw new ApiError(0, 'network', 'تعذّر الاتصال بالخادم، تحقق من الشبكة وحاول مرة أخرى')
  }

  if (res.status === 401 && !retried && path !== '/api/auth/verify-otp') {
    if (await refresh()) return send<T>(method, path, body, query, true)
    tokens.clear()
    onSessionExpired()
    throw new ApiError(401, 'session_expired', 'انتهت الجلسة، سجّل الدخول مرة أخرى')
  }
  if (!res.ok) throw await toError(res)
  if (res.status === 204) return undefined as T
  const text = await res.text()
  return (text ? JSON.parse(text) : undefined) as T
}

export const api = {
  get: <T>(path: string, query?: Query) => send<T>('GET', path, undefined, query),
  post: <T>(path: string, body?: unknown) => send<T>('POST', path, body ?? {}),
  put: <T>(path: string, body?: unknown) => send<T>('PUT', path, body ?? {}),
  patch: <T>(path: string, body?: unknown) => send<T>('PATCH', path, body ?? {}),
  del: <T>(path: string) => send<T>('DELETE', path),

  /** Image upload (banners, …) → stored URL path such as `/uploads/banners/2026-10/…jpg`. */
  async upload(folder: string, file: File): Promise<string> {
    const form = new FormData()
    form.append('file', file)
    const r = await send<{ url: string }>('POST', `/api/uploads/${folder}`, form)
    return r.url
  },
}

export const auth = {
  sendOtp: (phone: string) => api.post<OtpSent>('/api/auth/send-otp', { phone }),

  /** Admin sign-in (userType 4): only numbers that are already admins are accepted by the server. */
  async verifyOtp(phone: string, code: string): Promise<Account> {
    const r = await api.post<AuthResponse>('/api/auth/verify-otp', { phone, code, userType: 4 })
    tokens.save(r)
    return r.account
  },

  me: () => api.get<Account>('/api/auth/me'),

  async logout() {
    const token = tokens.refresh
    try {
      if (token) await api.post('/api/auth/logout', { refreshToken: token })
    } finally {
      tokens.clear()
    }
  },
}

/** Full URL for an image path from the API (`/uploads/...`) or a bundled asset name (`banner_1.jpg`). */
export function imageUrl(path: string | null | undefined): string | undefined {
  if (!path) return undefined
  if (path.startsWith('http') || path.startsWith('/uploads')) return path.startsWith('http') ? path : BASE + path
  return `/images/catalog/${path}`
}
