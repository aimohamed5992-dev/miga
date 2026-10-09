import { useCallback } from 'react'
import { useSearchParams } from 'react-router-dom'

/**
 * List state kept in the URL (so filters survive reloads and links can be shared): status tab, search, page.
 * Values equal to the defaults are removed from the URL.
 */
export function useListParams(defaultStatus: string) {
  const [params, setParams] = useSearchParams()
  const status = params.get('status') ?? defaultStatus
  const q = params.get('q') ?? ''
  const page = Number(params.get('page') ?? 1) || 1

  const set = useCallback(
    (changes: Record<string, string | number | null>) =>
      setParams(
        (p) => {
          for (const [k, v] of Object.entries(changes)) {
            if (v === null || v === '' || (k === 'status' && v === defaultStatus) || (k === 'page' && v === 1)) p.delete(k)
            else p.set(k, String(v))
          }
          return p
        },
        { replace: true },
      ),
    [setParams, defaultStatus],
  )

  return {
    params,
    status,
    q,
    page,
    set,
    setStatus: useCallback((v: string) => set({ status: v, page: null }), [set]),
    setQuery: useCallback((v: string) => set({ q: v, page: null }), [set]),
    setPage: useCallback((v: number) => set({ page: v }), [set]),
  }
}
