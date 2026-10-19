import React, { useState } from 'react'
import {
  Alert,
  AlertDescription,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Textarea,
} from '@myspace/ui'
import { CircleCheck, Lightbulb, TriangleAlert } from 'lucide-react'

interface IdeaFormProps {
  draft: string
  onDraftChange: (text: string) => void
  onSubmit: (content: string) => Promise<unknown>
  onClearDraft: () => void
  submitting: boolean
}

const MAX_CHAR_COUNT = 5000

export const IdeaForm: React.FC<IdeaFormProps> = ({
  draft,
  onDraftChange,
  onSubmit,
  onClearDraft,
  submitting,
}) => {
  const [successNotice, setSuccessNotice] = useState<string | null>(null)
  const [formError, setFormError] = useState<string | null>(null)

  const trimmed = draft.trim()
  const charCount = draft.length
  const isOverLimit = charCount > MAX_CHAR_COUNT
  const isValid = trimmed.length > 0 && !isOverLimit

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!isValid || submitting) return

    setFormError(null)
    setSuccessNotice(null)
    try {
      await onSubmit(draft)
      onClearDraft()
      setSuccessNotice('Your idea has been recorded securely!')
      setTimeout(() => setSuccessNotice(null), 4000)
    } catch (err: unknown) {
      const apiErr = err as { message?: string }
      setFormError(apiErr.message || 'Failed to submit idea. Please try again.')
    }
  }

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between gap-4">
        <CardTitle className="flex items-center gap-2">
          <Lightbulb aria-hidden="true" className="size-5" />
          Capture New Idea
        </CardTitle>
        <span
          className={`text-sm ${isOverLimit ? 'font-medium text-destructive' : 'text-muted-foreground'}`}
        >
          {charCount} / {MAX_CHAR_COUNT}
        </span>
      </CardHeader>

      <CardContent>
        <form onSubmit={handleSubmit} className="grid gap-4">
          <Textarea
            value={draft}
            onChange={(e) => {
              onDraftChange(e.target.value)
              if (formError) setFormError(null)
              if (successNotice) setSuccessNotice(null)
            }}
            placeholder="Type your innovative thought or concept here..."
            aria-label="Your idea"
            rows={5}
            invalid={isOverLimit}
            disabled={submitting}
            maxLength={MAX_CHAR_COUNT + 100}
          />

          {formError && (
            <Alert variant="destructive">
              <TriangleAlert aria-hidden="true" />
              <AlertDescription>{formError}</AlertDescription>
            </Alert>
          )}

          {successNotice && (
            <Alert variant="success">
              <CircleCheck aria-hidden="true" />
              <AlertDescription>{successNotice}</AlertDescription>
            </Alert>
          )}

          <div className="flex justify-end">
            <Button type="submit" disabled={!isValid || submitting}>
              {submitting ? 'Submitting...' : 'Submit Idea'}
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  )
}
