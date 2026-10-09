import clsx from 'clsx'
import type { ReactNode } from 'react'
import { Skeleton } from './ListControls'

export interface Column<T> {
  head: string
  cell: (row: T) => ReactNode
  className?: string
}

/** Admin table: sticky-looking header, skeleton rows while loading, dimmed while refetching, optional row click. */
export function DataTable<T extends { id: string }>({
  columns,
  rows,
  loading,
  fetching,
  onRowClick,
  selectedId,
  minWidth = 860,
}: {
  columns: Column<T>[]
  rows: T[] | undefined
  loading?: boolean
  fetching?: boolean
  onRowClick?: (row: T) => void
  selectedId?: string | null
  minWidth?: number
}) {
  return (
    <div className={clsx('overflow-x-auto transition-opacity', fetching && !loading && 'opacity-60')}>
      <table className="w-full text-sm" style={{ minWidth }}>
        <thead>
          <tr className="border-b border-line bg-canvas/60 text-xs text-muted">
            {columns.map((c) => (
              <th key={c.head} className={clsx('px-4 py-3 text-start font-bold whitespace-nowrap first:ps-6 last:pe-6', c.className)}>
                {c.head}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading || !rows
            ? Array.from({ length: 6 }, (_, i) => (
                <tr key={i} className="border-b border-line/60">
                  <td colSpan={columns.length} className="px-6 py-3">
                    <Skeleton className="h-10" />
                  </td>
                </tr>
              ))
            : rows.map((r) => (
                <tr
                  key={r.id}
                  onClick={onRowClick && (() => onRowClick(r))}
                  className={clsx(
                    'border-b border-line/60 align-middle transition-colors last:border-0',
                    onRowClick ? 'cursor-pointer hover:bg-brand-50/40' : 'hover:bg-canvas/50',
                    selectedId === r.id && 'bg-brand-50/60',
                  )}
                >
                  {columns.map((c) => (
                    <td key={c.head} className={clsx('px-4 py-3 first:ps-6 last:pe-6', c.className)}>
                      {c.cell(r)}
                    </td>
                  ))}
                </tr>
              ))}
        </tbody>
      </table>
    </div>
  )
}
