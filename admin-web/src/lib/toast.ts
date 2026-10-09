import { createContext, useContext } from 'react'

export type ToastTone = 'ok' | 'error'
export const ToastContext = createContext<(message: string, tone?: ToastTone) => void>(() => {})

/** `toast('تم الحفظ')` / `toast(err.message, 'error')` — short confirmation at the bottom of the screen. */
export const useToast = () => useContext(ToastContext)
