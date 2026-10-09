import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react'
import { auth, hasSession, setSessionExpiredHandler, type Account } from '../lib/api'
import { AuthContext } from './authState'


export function AuthProvider({ children }: { children: ReactNode }) {
  const [account, setAccount] = useState<Account | null>(null)
  const [restoring, setRestoring] = useState(hasSession())

  useEffect(() => {
    setSessionExpiredHandler(() => setAccount(null))
    if (!hasSession()) return
    auth
      .me()
      .then((a) => setAccount(a.userType === 4 ? a : null))
      .catch(() => setAccount(null))
      .finally(() => setRestoring(false))
  }, [])

  const signOut = useCallback(async () => {
    try {
      await auth.logout()
    } finally {
      setAccount(null)
    }
  }, [])

  const value = useMemo(() => ({ account, restoring, signedIn: setAccount, signOut }), [account, restoring, signOut])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
