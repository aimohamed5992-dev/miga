import { createContext, useContext } from 'react'
import type { Account } from '../lib/api'

export interface AuthState {
  account: Account | null
  /** True while the saved session is being checked on load. */
  restoring: boolean
  signedIn: (a: Account) => void
  signOut: () => Promise<void>
}

export const AuthContext = createContext<AuthState | null>(null)

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth outside AuthProvider')
  return ctx
}
