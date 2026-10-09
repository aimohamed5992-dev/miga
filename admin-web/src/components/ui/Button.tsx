import clsx from 'clsx'
import type { ButtonHTMLAttributes, ReactNode } from 'react'
import { Spinner } from './Spinner'

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger' | 'dark'
type Size = 'sm' | 'md' | 'lg'

const variants: Record<Variant, string> = {
  primary: 'bg-brand-600 text-white hover:bg-brand-700 shadow-brand focus-visible:ring-brand-300',
  secondary: 'bg-white text-ink border border-line hover:border-brand-300 hover:text-brand-700 focus-visible:ring-brand-200',
  ghost: 'text-ink-3 hover:bg-black/5 focus-visible:ring-black/10',
  danger: 'bg-danger text-white hover:brightness-95 focus-visible:ring-danger/30',
  dark: 'bg-brand-800 text-white hover:bg-brand-900 focus-visible:ring-brand-200',
}
const sizes: Record<Size, string> = {
  sm: 'h-9 px-3.5 text-sm gap-1.5 rounded-xl',
  md: 'h-11 px-5 text-[15px] gap-2 rounded-xl',
  lg: 'h-13 px-6 text-base gap-2.5 rounded-2xl',
}

interface Props extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant
  size?: Size
  loading?: boolean
  icon?: ReactNode
  block?: boolean
}

export function Button({ variant = 'primary', size = 'md', loading, icon, block, className, children, disabled, ...rest }: Props) {
  return (
    <button
      {...rest}
      disabled={disabled || loading}
      className={clsx(
        'inline-flex shrink-0 select-none items-center justify-center font-bold whitespace-nowrap transition-all outline-none focus-visible:ring-4',
        'disabled:cursor-not-allowed disabled:opacity-50 disabled:shadow-none active:scale-[0.98]',
        variants[variant],
        sizes[size],
        block && 'w-full',
        className,
      )}
    >
      {loading ? <Spinner className="size-5" /> : icon}
      {children}
    </button>
  )
}
