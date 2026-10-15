import { generateCodeChallenge, generateCodeVerifier, generateState } from './pkce'
import { setStoredToken } from './api'

const COGNITO_DOMAIN = (import.meta.env.VITE_COGNITO_DOMAIN || '').replace(/\/$/, '')
const COGNITO_CLIENT_ID = import.meta.env.VITE_COGNITO_CLIENT_ID || ''
const COGNITO_REDIRECT_URI = import.meta.env.VITE_COGNITO_REDIRECT_URI || window.location.origin

const STORAGE_KEY_ACCESS_TOKEN = 'ideacollector_access_token'
const STORAGE_KEY_ID_TOKEN = 'ideacollector_id_token'
const STORAGE_KEY_REFRESH_TOKEN = 'ideacollector_refresh_token'
const STORAGE_KEY_EXPIRES_AT = 'ideacollector_expires_at'
const SESSION_KEY_CODE_VERIFIER = 'ideacollector_pkce_verifier'
const SESSION_KEY_OAUTH_STATE = 'ideacollector_oauth_state'

export interface UserClaims {
  sub: string
  email: string
  name?: string
  exp: number
}

export interface TokenResponse {
  access_token: string
  id_token: string
  refresh_token?: string
  token_type: string
  expires_in: number
}

function parseJwt<T = Record<string, unknown>>(token: string): T | null {
  try {
    const base64Url = token.split('.')[1]
    const base64 = base64Url.replace(/-/g, '+').replace(/_/g, '/')
    const jsonPayload = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2))
        .join('')
    )
    return JSON.parse(jsonPayload) as T
  } catch (err) {
    console.error('Failed to parse JWT token:', err)
    return null
  }
}

export const authService = {
  /**
   * Initiates direct 1-click federated Google authentication via AWS Cognito
   */
  async initiateGoogleLogin(): Promise<void> {
    const verifier = generateCodeVerifier(64)
    const challenge = await generateCodeChallenge(verifier)
    const state = generateState(32)

    sessionStorage.setItem(SESSION_KEY_CODE_VERIFIER, verifier)
    sessionStorage.setItem(SESSION_KEY_OAUTH_STATE, state)

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: COGNITO_CLIENT_ID,
      redirect_uri: COGNITO_REDIRECT_URI,
      identity_provider: 'Google',
      scope: 'openid email profile',
      code_challenge: challenge,
      code_challenge_method: 'S256',
      state,
    })

    const authorizeUrl = `${COGNITO_DOMAIN}/oauth2/authorize?${params.toString()}`
    window.location.href = authorizeUrl
  },

  /**
   * Exchanges authorization code for Cognito tokens upon redirect back from Google
   */
  async handleCallback(code: string, state: string): Promise<UserClaims> {
    const storedState = sessionStorage.getItem(SESSION_KEY_OAUTH_STATE)
    if (storedState && storedState !== state) {
      throw new Error('OAuth state mismatch: potential CSRF request')
    }

    const codeVerifier = sessionStorage.getItem(SESSION_KEY_CODE_VERIFIER)
    if (!codeVerifier) {
      throw new Error('PKCE code_verifier not found in session storage')
    }

    const bodyParams = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: COGNITO_CLIENT_ID,
      code,
      redirect_uri: COGNITO_REDIRECT_URI,
      code_verifier: codeVerifier,
    })

    const response = await fetch(`${COGNITO_DOMAIN}/oauth2/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: bodyParams.toString(),
    })

    if (!response.ok) {
      const errText = await response.text().catch(() => '')
      throw new Error(`Token exchange failed (${response.status}): ${errText}`)
    }

    const tokenData = (await response.json()) as TokenResponse
    this.storeTokens(tokenData)

    // Clean up temporary PKCE values
    sessionStorage.removeItem(SESSION_KEY_CODE_VERIFIER)
    sessionStorage.removeItem(SESSION_KEY_OAUTH_STATE)

    const claims = parseJwt<UserClaims>(tokenData.id_token)
    if (!claims) {
      throw new Error('Unable to parse ID token claims')
    }

    return claims
  },

  /**
   * Stores Cognito tokens in local storage and configures API Bearer token
   */
  storeTokens(tokens: TokenResponse): void {
    localStorage.setItem(STORAGE_KEY_ACCESS_TOKEN, tokens.access_token)
    localStorage.setItem(STORAGE_KEY_ID_TOKEN, tokens.id_token)
    if (tokens.refresh_token) {
      localStorage.setItem(STORAGE_KEY_REFRESH_TOKEN, tokens.refresh_token)
    }
    const expiresAt = Date.now() + tokens.expires_in * 1000
    localStorage.setItem(STORAGE_KEY_EXPIRES_AT, expiresAt.toString())

    // Update API client bearer token with Cognito Access Token
    setStoredToken(tokens.access_token)
  },

  /**
   * Refreshes Cognito tokens using stored refresh_token
   */
  async refreshTokens(): Promise<string | null> {
    const refreshToken = localStorage.getItem(STORAGE_KEY_REFRESH_TOKEN)
    if (!refreshToken) {
      return null
    }

    const bodyParams = new URLSearchParams({
      grant_type: 'refresh_token',
      client_id: COGNITO_CLIENT_ID,
      refresh_token: refreshToken,
    })

    const response = await fetch(`${COGNITO_DOMAIN}/oauth2/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: bodyParams.toString(),
    })

    if (!response.ok) {
      this.clearTokens()
      return null
    }

    const tokenData = (await response.json()) as TokenResponse
    this.storeTokens(tokenData)
    return tokenData.access_token
  },

  /**
   * Retrieves current user claims if an active, non-expired session exists
   */
  getCurrentUser(): UserClaims | null {
    const idToken = localStorage.getItem(STORAGE_KEY_ID_TOKEN)
    const expiresAtStr = localStorage.getItem(STORAGE_KEY_EXPIRES_AT)
    if (!idToken || !expiresAtStr) {
      return null
    }

    const expiresAt = parseInt(expiresAtStr, 10)
    if (Date.now() >= expiresAt) {
      return null
    }

    return parseJwt<UserClaims>(idToken)
  },

  /**
   * Clears tokens and terminates session state
   */
  clearTokens(): void {
    localStorage.removeItem(STORAGE_KEY_ACCESS_TOKEN)
    localStorage.removeItem(STORAGE_KEY_ID_TOKEN)
    localStorage.removeItem(STORAGE_KEY_REFRESH_TOKEN)
    localStorage.removeItem(STORAGE_KEY_EXPIRES_AT)
    setStoredToken(null)
  },
}
