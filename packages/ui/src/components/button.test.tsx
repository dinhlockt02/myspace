import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import { Button } from './button'

describe('Button accessible names', () => {
  it('exposes the aria-label of an icon button as its name', () => {
    render(
      <Button size="icon" aria-label="Add item">
        <svg aria-hidden="true" />
      </Button>,
    )
    expect(screen.getByRole('button', { name: 'Add item' })).toBeTruthy()
  })

  it('exposes aria-labelledby as the name of an icon button', () => {
    render(
      <>
        <span id="label">Delete idea</span>
        <Button size="icon" aria-labelledby="label" />
      </>,
    )
    expect(screen.getByRole('button', { name: 'Delete idea' })).toBeTruthy()
  })
})

// Compile-time contract: `pnpm nx run ui:typecheck` fails if any @ts-expect-error below stops being an error.
// Never called; it only has to type-check.
export const iconButtonTypeContract = () => (
  <>
    {/* @ts-expect-error an icon button needs aria-label or aria-labelledby */}
    <Button size="icon" />
    {/* @ts-expect-error an icon button needs aria-label or aria-labelledby */}
    <Button size="icon">+</Button>
    <Button size="icon" aria-label="Allowed" />
    <Button size="icon" aria-labelledby="allowed" />
    <Button>Text buttons need nothing extra</Button>
    <Button size="sm">Small</Button>
  </>
)
