const FOCUSABLE = "a[href], button:not([disabled]), input:not([disabled]):not([type=hidden]), select, textarea, summary, [tabindex]:not([tabindex='-1'])"

// Keeps Tab inside an open layer, so the page behind it cannot be reached by keyboard.
export function keepFocusInside(container, event) {
  if (event.key !== "Tab") return

  const stops = [ ...container.querySelectorAll(FOCUSABLE) ].filter((element) => element.offsetParent !== null)
  if (stops.length === 0) return

  const first = stops[0]
  const last = stops[stops.length - 1]

  if (event.shiftKey && document.activeElement === first) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && document.activeElement === last) {
    event.preventDefault()
    first.focus()
  }
}

export function giveFocusBack(element) {
  if (element && element.isConnected) element.focus()
}
