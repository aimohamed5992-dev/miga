import { lazy, Suspense, type ReactNode } from 'react'
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { AuthProvider } from './auth/AuthContext'
import { useAuth } from './auth/authState'
import { Logo } from './components/ui/Logo'
import { Spinner } from './components/ui/Spinner'
import { AppShell } from './layout/AppShell'
import { BannersPage } from './pages/BannersPage'
import { CampaignsPage } from './pages/CampaignsPage'
import { DashboardPage } from './pages/DashboardPage'
import { DeliveriesPage } from './pages/DeliveriesPage'
import { LoginPage } from './pages/LoginPage'
import { NotFoundPage } from './pages/NotFoundPage'
import { OrdersPage } from './pages/OrdersPage'
import { PayoutsPage } from './pages/PayoutsPage'
import { SettingsPage } from './pages/SettingsPage'
import { UsersPage } from './pages/UsersPage'
import { VerificationsPage } from './pages/VerificationsPage'

// The map pulls in Leaflet; load it only when opened.
const MapPage = lazy(() => import('./pages/MapPage').then((m) => ({ default: m.MapPage })))

function Splash() {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-6 bg-gradient-to-br from-brand-600 to-brand-800">
      <Logo light size={56} />
      <Spinner className="size-7 text-white" />
    </div>
  )
}

/** Admin-only routes: waits for the saved session, otherwise sends to /login and back afterwards. */
function RequireAdmin({ children }: { children: ReactNode }) {
  const { account, restoring } = useAuth()
  const location = useLocation()
  if (restoring) return <Splash />
  if (!account) return <Navigate to="/login" replace state={{ from: location.pathname + location.search }} />
  return children
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            element={
              <RequireAdmin>
                <AppShell />
              </RequireAdmin>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route
              path="map"
              element={
                <Suspense fallback={<Spinner className="mx-auto mt-24 size-8 text-brand-600" />}>
                  <MapPage />
                </Suspense>
              }
            />
            <Route path="verifications" element={<VerificationsPage />} />
            <Route path="merchants" element={<UsersPage key="merchant" kind="merchant" />} />
            <Route path="drivers" element={<UsersPage key="driver" kind="driver" />} />
            <Route path="customers" element={<UsersPage key="customer" kind="customer" />} />
            <Route path="campaigns" element={<CampaignsPage />} />
            <Route path="orders" element={<OrdersPage />} />
            <Route path="deliveries" element={<DeliveriesPage />} />
            <Route path="payouts" element={<PayoutsPage />} />
            <Route path="banners" element={<BannersPage />} />
            <Route path="settings" element={<SettingsPage />} />
            <Route path="*" element={<NotFoundPage />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
