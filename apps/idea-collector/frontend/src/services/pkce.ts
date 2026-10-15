/**
 * PKCE (Proof Key for Code Exchange) Utility Functions
 * Conforms to RFC 7636 for secure Single Page Application OAuth2 authorization flows.
 */

// Base64URL encoding without '=' padding
function base64UrlEncode(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer)
  let binary = ''
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i])
  }
  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

/**
 * Generates a cryptographically random code_verifier string (43 - 128 characters)
 */
export function generateCodeVerifier(length = 64): string {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~'
  const randomValues = new Uint8Array(length)
  crypto.getRandomValues(randomValues)
  let verifier = ''
  for (let i = 0; i < length; i++) {
    verifier += charset[randomValues[i] % charset.length]
  }
  return verifier
}

/**
 * Calculates SHA-256 hash of code_verifier and returns base64url-encoded code_challenge
 */
export async function generateCodeChallenge(verifier: string): Promise<string> {
  const encoder = new TextEncoder()
  const data = encoder.encode(verifier)
  const digest = await crypto.subtle.digest('SHA-256', data)
  return base64UrlEncode(digest)
}

/**
 * Generates a random state string to mitigate CSRF attacks
 */
export function generateState(length = 32): string {
  const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  const randomValues = new Uint8Array(length)
  crypto.getRandomValues(randomValues)
  let state = ''
  for (let i = 0; i < length; i++) {
    state += charset[randomValues[i] % charset.length]
  }
  return state
}
