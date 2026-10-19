import { describe, expect, it } from 'vitest'
import { cn } from './cn'

describe('cn', () => {
  it('merges conflicting Tailwind utilities, keeping the last one', () => {
    expect(cn('p-2', 'p-4')).toBe('p-4')
    expect(cn('text-sm text-muted-foreground', 'text-foreground')).toBe('text-sm text-foreground')
  })

  it('drops falsy values', () => {
    const zero = 0
    expect(cn('a', false, null, undefined, zero, '', 'c')).toBe('a c')
  })

  it('supports conditional classes', () => {
    const active = true
    const disabled = false
    expect(cn('base', { 'is-active': active, 'is-disabled': disabled })).toBe('base is-active')
  })

  it('flattens arrays', () => {
    expect(cn(['a', ['b', 'c']], 'd')).toBe('a b c d')
  })
})
