// `ring-*` focus indicators are box-shadows, which forced colors mode (Windows High Contrast) removes.
// This outline takes over only in that mode, so the focus indicator stays visible there and nothing
// changes elsewhere. Add it next to any `focus-visible:ring-*` on an element that sets `outline-none`.
export const forcedColorsFocus =
  'forced-colors:focus-visible:outline-2 forced-colors:focus-visible:outline-solid forced-colors:focus-visible:outline-offset-2'
