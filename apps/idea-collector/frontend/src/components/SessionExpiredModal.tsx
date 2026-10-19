import React from 'react'
import {
  Alert,
  AlertDescription,
  Button,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
  GoogleIcon,
} from '@myspace/ui'
import { Hourglass, ShieldCheck } from 'lucide-react'
import { authService } from '../services/auth'

interface SessionExpiredModalProps {
  isOpen: boolean
  onSuccess?: () => void
}

export const SessionExpiredModal: React.FC<SessionExpiredModalProps> = ({ isOpen }) => {
  if (!isOpen) return null

  const handleReauth = async () => {
    try {
      await authService.initiateGoogleLogin()
    } catch (err) {
      console.error('Failed to initiate Google re-authentication:', err)
    }
  }

  // Not dismissible: the user has to sign in again to continue, exactly as before
  return (
    <Dialog open dismissible={false}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle className="flex items-center justify-center gap-2 sm:justify-start">
            <Hourglass aria-hidden="true" className="size-5" />
            Session Expired
          </DialogTitle>
          <DialogDescription>
            Your session has timed out due to <strong>1 hour of idle inactivity</strong>.
          </DialogDescription>
        </DialogHeader>

        <Alert variant="info">
          <ShieldCheck aria-hidden="true" />
          <AlertDescription>
            Your unsubmitted draft idea has been safely preserved! Sign in below to continue writing and submit.
          </AlertDescription>
        </Alert>

        <Button type="button" variant="outline" size="lg" className="w-full" onClick={handleReauth}>
          <GoogleIcon />
          <span>Sign in with Google to Resume</span>
        </Button>
      </DialogContent>
    </Dialog>
  )
}
