import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// In development the API is proxied, so the dashboard talks to /api on its own origin (no CORS needed).
// For production builds set VITE_API_URL (e.g. https://api.miga.sa).
const api = process.env.MIGA_API_URL ?? 'http://localhost:5296'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    port: 5173,
    proxy: {
      '/api': { target: api, changeOrigin: true },
      '/uploads': { target: api, changeOrigin: true },
    },
  },
})
