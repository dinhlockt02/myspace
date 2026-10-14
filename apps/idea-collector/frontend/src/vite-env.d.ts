/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_URL: string
  readonly VITE_GOOGLE_CLIENT_ID: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

declare namespace google {
  namespace accounts {
    namespace id {
      function initialize(config: {
        client_id: string
        callback: (response: { credential: string }) => void
        auto_select?: boolean
        cancel_on_tap_outside?: boolean
      }): void
      function renderButton(
        parent: HTMLElement,
        options: {
          theme?: 'outline' | 'filled_blue' | 'filled_black'
          size?: 'large' | 'medium' | 'small'
          text?: 'signin_with' | 'signup_with' | 'continue_with' | 'signin'
          shape?: 'rectangular' | 'pill' | 'circle' | 'square'
          width?: string | number
        }
      ): void
      function prompt(notification?: (notification: unknown) => void): void
      function disableAutoSelect(): void
    }
  }
}
