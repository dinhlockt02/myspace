import { describe, expect, it } from 'vitest'
import { render, screen } from '@testing-library/react'
import { IdeaList } from './IdeaList'
import type { IdeaItem } from '../services/api'

const idea = (id: string, text: string): IdeaItem => ({
  id,
  idea: text,
  client_timestamp: 1_700_000_000_000,
  server_timestamp: 1_700_000_001_000,
})

describe('IdeaList', () => {
  it('shows loading when there are no ideas yet', () => {
    render(<IdeaList ideas={[]} loading />)
    expect(screen.getByRole('heading', { name: 'Your Collection' })).toBeInTheDocument()
    expect(screen.getByText('Loading your ideas...')).toBeInTheDocument()
  })

  it('shows the empty state', () => {
    render(<IdeaList ideas={[]} loading={false} />)
    expect(screen.getByRole('heading', { name: 'Your Collection' })).toBeInTheDocument()
    expect(screen.getByText('No ideas submitted yet')).toBeInTheDocument()
  })

  it('lists every idea with a count', () => {
    render(<IdeaList ideas={[idea('1', 'First thought'), idea('2', 'Second thought')]} loading={false} />)
    expect(screen.getByRole('heading', { name: 'Your Collection' })).toBeInTheDocument()
    expect(screen.getByText('First thought')).toBeInTheDocument()
    expect(screen.getByText('Second thought')).toBeInTheDocument()
    expect(screen.getByText('2 ideas')).toBeInTheDocument()
  })

  it('uses the singular for one idea', () => {
    render(<IdeaList ideas={[idea('1', 'Only thought')]} loading={false} />)
    expect(screen.getByText('1 idea')).toBeInTheDocument()
  })
})
