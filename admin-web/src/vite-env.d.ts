/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL?: string
  /** Map tile URL template for the live map (defaults to OpenStreetMap). */
  readonly VITE_MAP_TILES_URL?: string
  readonly VITE_MAP_TILES_ATTRIBUTION?: string
}
