import clsx from 'clsx'
import { ImageIcon } from 'lucide-react'
import { useState } from 'react'

/**
 * Admin artwork from /public/images (see docs/ADMIN_IMAGE_PROMPTS.md). Until the file exists it shows a soft branded
 * placeholder of the same size, so layouts never jump or break.
 */
export function Illustration({
  name,
  alt = '',
  className,
  hideIfMissing = false,
}: {
  name: string
  alt?: string
  className?: string
  /** On dark or decorative areas show nothing rather than a light placeholder box. */
  hideIfMissing?: boolean
}) {
  const [missing, setMissing] = useState(false)
  if (missing && hideIfMissing) return null
  if (missing) {
    return (
      <div className={clsx('flex items-center justify-center rounded-3xl bg-gradient-to-br from-brand-50 to-white', className)}>
        <div className="flex size-20 items-center justify-center rounded-full bg-white text-brand-300 shadow-card">
          <ImageIcon className="size-9" />
        </div>
      </div>
    )
  }
  return <img src={`/images/${name}.png`} alt={alt} className={clsx('object-contain', className)} onError={() => setMissing(true)} />
}
