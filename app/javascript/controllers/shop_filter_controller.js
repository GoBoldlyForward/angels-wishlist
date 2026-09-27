import { Controller } from "@hotwired/stimulus"

// The filter pills are <details>, so they open without JavaScript. This keeps one open at a time.
export default class extends Controller {
  static targets = [ "drop" ]

  closeOthers(event) {
    if (!event.target.open) return

    this.dropTargets.forEach((drop) => { if (drop !== event.target) drop.open = false })
  }

  closeOutside(event) {
    this.dropTargets.forEach((drop) => { if (!drop.contains(event.target)) drop.open = false })
  }

  closeAll() {
    this.dropTargets.forEach((drop) => {
      if (drop.open && drop.contains(document.activeElement)) drop.querySelector("summary").focus()
      drop.open = false
    })
  }
}
