const API_BASE_URL = import.meta.env.VITE_API_URL || ''

export interface UserDTO {
  id: string
  email: string
}

export interface AuthSessionResponse {
  session_token: string
  expires_in: number
  user: UserDTO
}

export interface UserProfileResponse {
  user: UserDTO
  idle_expires_in: number
}

export interface IdeaItem {
  id: string
  idea: string
  client_timestamp: number
  server_timestamp: number
}

export interface ApiError {
  error: string
  message: string
}

let sessionExpiredHandler: (() => void) | null = null

export function onSessionExpired(handler: () => void) {
  sessionExpiredHandler = handler
}

export function getStoredToken(): string | null {
  return localStorage.getItem('ideacollector_session_token')
}

export function setStoredToken(token: string | null) {
  if (token) {
    localStorage.setItem('ideacollector_session_token', token)
  } else {
    localStorage.removeItem('ideacollector_session_token')
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getStoredToken()
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(options.headers as Record<string, string>),
  }

  if (token) {
    headers['Authorization'] = `Bearer ${token}`
  }

  const url = `${API_BASE_URL}${path}`
  const response = await fetch(url, {
    ...options,
    headers,
  })

  if (response.status === 401) {
    if (sessionExpiredHandler) {
      sessionExpiredHandler()
    }
    const errData = await response.json().catch(() => ({
      error: 'UNAUTHORIZED',
      message: 'Session has expired or is invalid. Please sign in again.',
    }))
    throw errData
  }

  if (!response.ok) {
    const errData = await response.json().catch(() => ({
      error: 'HTTP_ERROR',
      message: `Request failed with status ${response.status}`,
    }))
    throw errData
  }

  return response.json() as Promise<T>
}

export const api = {
  async authenticateWithGoogle(idToken: string): Promise<AuthSessionResponse> {
    const res = await request<AuthSessionResponse>('/api/auth/google', {
      method: 'POST',
      body: JSON.stringify({ id_token: idToken }),
    })
    setStoredToken(res.session_token)
    return res
  },

  async getProfile(): Promise<UserProfileResponse> {
    return request<UserProfileResponse>('/api/auth/me', {
      method: 'GET',
    })
  },

  async logout(): Promise<{ success: boolean; message: string }> {
    try {
      return await request<{ success: boolean; message: string }>('/api/auth/logout', {
        method: 'POST',
      })
    } finally {
      setStoredToken(null)
    }
  },

  async submitIdea(idea: string, timestamp: number = Date.now()): Promise<{ success: boolean; id: string; message: string }> {
    return request<{ success: boolean; id: string; message: string }>('/api/ideas', {
      method: 'POST',
      body: JSON.stringify({ idea, timestamp }),
    })
  },

  async listIdeas(): Promise<{ ideas: IdeaItem[] }> {
    return request<{ ideas: IdeaItem[] }>('/api/ideas', {
      method: 'GET',
    })
  },

  async inviteUser(email: string): Promise<{ success: boolean; message: string; email: string }> {
    return request<{ success: boolean; message: string; email: string }>('/api/invitations', {
      method: 'POST',
      body: JSON.stringify({ email }),
    })
  },
}
