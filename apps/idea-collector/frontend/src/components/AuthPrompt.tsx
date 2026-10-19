import React from 'react'
import {
  Alert,
  AlertDescription,
  Button,
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
  GoogleIcon,
  Spinner,
} from '@myspace/ui'
import { Lightbulb, TriangleAlert } from 'lucide-react'
import { authService } from '../services/auth'

interface AuthPromptProps {
  error: string | null
  loading: boolean
}

export const AuthPrompt: React.FC<AuthPromptProps> = ({ error, loading }) => {
  const handleGoogleSignIn = async () => {
    try {
      await authService.initiateGoogleLogin()
    } catch (err) {
      console.error('Failed to initiate Google sign-in:', err)
    }
  }

  return (
    <Card className="w-full max-w-md">
      <CardHeader className="items-center text-center">
        <span className="mb-2 flex size-12 items-center justify-center rounded-full bg-secondary text-secondary-foreground">
          <Lightbulb aria-hidden="true" className="size-6" />
        </span>
        <CardTitle as="h2" className="text-2xl">
          Welcome to Idea Collector
        </CardTitle>
        <CardDescription>
          Capture and organize your thoughts in a private, isolated workspace. Open to everyone — no invitation required!
        </CardDescription>
      </CardHeader>

      <CardContent className="grid gap-4">
        {error && (
          <Alert variant="destructive">
            <TriangleAlert aria-hidden="true" />
            <AlertDescription>{error}</AlertDescription>
          </Alert>
        )}

        {loading ? (
          <div className="flex flex-col items-center gap-2 text-sm text-muted-foreground">
            <Spinner label="Signing in" />
            <p>Signing in...</p>
          </div>
        ) : (
          <Button
            type="button"
            variant="outline"
            size="lg"
            className="w-full"
            onClick={handleGoogleSignIn}
            aria-label="Sign in with Google"
          >
            <GoogleIcon size={22} />
            <span>Sign in with Google</span>
          </Button>
        )}
      </CardContent>

      <CardFooter>
        <p className="text-center text-sm text-muted-foreground">
          Signing in automatically provisions your personal workspace via secure federated authentication.
        </p>
      </CardFooter>
    </Card>
  )
}
