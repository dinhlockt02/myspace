# UI Package API Contract: `@myspace/ui`

**Feature**: `004-design-system` | Public surface of `packages/ui` (FR-002, FR-003, FR-006, FR-008, FR-011, FR-012, FR-014).

## Package exports

| Export path | Provides |
| :--- | :--- |
| `@myspace/ui` | All components, layout primitives, `cn`, `ThemeProvider`, `useTheme`, `GoogleIcon` |
| `@myspace/ui/theme.css` | Tokens, `@theme inline` mapping, dark variant, animation import. No base reset |
| `@myspace/ui/theme-init` | The source of the blocking theme script, as a string, for `index.html` |

The package is consumed from source (`exports` point at `src/`). Lucide icons are imported by applications directly from `lucide-react`; the package re-exports none of them.

## Shared rules (apply to every component)

- Implements the six states in the data model: default, hover, focus, active, disabled, error where applicable.
- Visible focus uses `ring-ring`; focus is never removed.
- Disabled controls are not focusable; error state sets `aria-invalid="true"` and links the message with `aria-describedby`.
- Icons are decorative (`aria-hidden="true"`) unless an accessible name is supplied.
- Styling is Tailwind utilities from the tokens; no raw colors, no element selectors.
- Props extend the matching native element or Radix part, `className` merges through `cn`, and `ref` is forwarded.

## Components (FR-014)

| Component | Foundation | Props beyond the native element | Accessibility and keyboard |
| :--- | :--- | :--- | :--- |
| `Button` | native `<button>` / Slot | `variant`: default, secondary, outline, ghost, destructive, link; `size`: sm, default, lg, icon; `asChild` | Enter and Space activate; `icon` size requires an accessible name |
| `Input` | native `<input>` | `invalid` | Tab focus; label association is the caller's responsibility; `aria-invalid` when invalid |
| `Textarea` | native `<textarea>` | `invalid` | As `Input` |
| `Card` (+ `CardHeader`, `CardTitle`, `CardDescription`, `CardContent`, `CardFooter`) | native `<div>` | none | Non-interactive container; `CardTitle` renders a heading element chosen by `as` |
| `Dialog` (+ `DialogTrigger`, `DialogContent`, `DialogHeader`, `DialogTitle`, `DialogDescription`, `DialogFooter`, `DialogClose`) | Radix Dialog | `dismissible` (default `true`) | Focus trapped; focus restored on close; Escape, close button and backdrop dismiss when `dismissible`; with `dismissible={false}` none of these dismiss and no close button renders; `DialogTitle` and `DialogDescription` required |
| `Alert` (+ `AlertTitle`, `AlertDescription`) | native `<div>` | `variant`: default, destructive, success, warning, info | `role="alert"` for destructive and warning, `role="status"` for the others; optional Lucide icon, decorative |
| `Select` (+ `SelectTrigger`, `SelectContent`, `SelectItem`, `SelectValue`) | Radix Select | `invalid` | Arrow keys move, Enter or Space select, Escape closes, type-ahead |
| `Checkbox` | Radix Checkbox | `invalid` | Space toggles; indeterminate supported |
| `RadioGroup` (+ `RadioGroupItem`) | Radix RadioGroup | `invalid` | Arrow keys move and select, Tab leaves the group |
| `Tooltip` (+ `TooltipProvider`, `TooltipTrigger`, `TooltipContent`) | Radix Tooltip | none | Opens on hover and keyboard focus; Escape closes; content is never the only way to get information |
| `Spinner` | Lucide `LoaderCircle` | `size`: sm, default, lg; `label` (default "Loading") | `role="status"` with a visually hidden label |
| `Badge` | native `<span>` | `variant`: default, secondary, outline, destructive | Non-interactive |

## Layout primitives (FR-011)

| Component | Props | Slots | Responsive behavior |
| :--- | :--- | :--- | :--- |
| `PageContainer` | `as`, `className` | children | Full width with horizontal padding below 640px; centered with a maximum width from 1024px up |
| `AppHeader` | `className` | `brand`, `actions` | Row layout; below 640px the actions wrap under the brand without horizontal overflow |
| `SidebarLayout` | `sidebarWidth`, `className` | `sidebar`, children | Sidebar and content side by side from 1024px; stacked below |

## Theme API

| Export | Contract |
| :--- | :--- |
| `ThemeProvider` | Props `defaultTheme` (default `system`), `storageKey` (default `ui-theme`). Applies the `.dark` class and `color-scheme` to `<html>`, follows `prefers-color-scheme` while the value is `system`, tolerates unavailable storage |
| `useTheme()` | Returns `{ theme, resolvedTheme, setTheme }` with `theme` in `light`, `dark`, `system` and `resolvedTheme` in `light`, `dark` |
| `theme-init` | Script that reads `ui-theme` (default `system`), resolves it and sets the `.dark` class before first paint; must run inline in `<head>` |

Switching themes sets `data-theme-switching` on `<html>` for one frame so no transition runs half-way.

## Icons (FR-012)

- Interface icons: `lucide-react`, imported by the application.
- `GoogleIcon` (exported by `@myspace/ui`): the multi-colour Google "G", props `size` (default 20), decorative by default. It exists because Lucide 1.x ships no brand logos.

## Testing contract

For each component the package provides stories covering every variant and state, in both themes, plus:

- an axe run that fails on any violation (SC-002, FR-015);
- a `play` function for each interactive component exercising its keyboard behavior from the table above (FR-006);
- for layout primitives, a responsive check with no horizontal overflow at 320, 375, 640, 1024 and 2560 px (SC-004).

## Out of scope for the first release

Tabs, toast, popover, switch and any other component not listed above (FR-014).
