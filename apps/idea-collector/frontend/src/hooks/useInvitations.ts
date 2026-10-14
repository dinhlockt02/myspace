import { useState } from 'react'
import { api } from '../services/api'

export function useInvitations() {
  const [inviting, setInviting] = useState<boolean>(false)
  const [error, setError] = useState<string | null>(null)
  const [successEmail, setSuccessEmail] = useState<string | null>(null)

  const sendInvitation = async (email: string) => {
    setInviting(true)
    setError(null)
    setSuccessEmail(null)
    try {
      const res = await api.inviteUser(email)
      setSuccessEmail(res.email)
      return res
    } catch (err: unknown) {
      const apiErr = err as { message?: string }
      const msg = apiErr.message || 'Failed to send invitation.'
      setError(msg)
      throw new Error(msg)
    } finally {
      setInviting(false)
    }
  }

  const resetStatus = () => {
    setError(null)
    setSuccessEmail(null)
  }

  return {
    inviting,
    error,
    successEmail,
    sendInvitation,
    resetStatus,
  }
}
