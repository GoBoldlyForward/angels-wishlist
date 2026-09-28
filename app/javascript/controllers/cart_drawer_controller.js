import { Controller } from "@hotwired/stimulus"
import { keepFocusInside, giveFocusBack } from "controllers/shop_focus"

// The cart button is a link to the cart page. With JavaScript it opens the drawer instead.
export default class extends Controller {
  static targets = [ "drawer", "scrim", "close", "button" ]
  static values = { open: Boolean }

  connect() {
    if (!this.openValue) return

    // A page restored from Turbo's cache should not open the drawer a second time.
    this.openValue = false
    this.returnTo = this.hasButtonTarget ? this.buttonTarget : null
    this.show()
    this.celebrate()
  }

  open(event) {
    event.preventDefault()
    this.returnTo = event.currentTarget
    this.show()
  }

  close() {
    if (!this.isOpen) return

    this.drawerTarget.classList.remove("on", "cascade")
    this.scrimTarget.classList.remove("on")
    this.hiding = setTimeout(() => { this.drawerTarget.hidden = true }, 260)
    giveFocusBack(this.returnTo)
  }

  keepFocus(event) {
    keepFocusInside(this.drawerTarget, event)
  }

  show() {
    clearTimeout(this.hiding)
    this.drawerTarget.hidden = false
    void this.drawerTarget.offsetWidth
    this.drawerTarget.classList.add("on", "cascade")
    this.scrimTarget.classList.add("on")
    this.closeTarget.focus()
  }

  celebrate() {
    if (!this.hasButtonTarget || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.buttonTarget.classList.add("bump")
  }

  get isOpen() {
    return this.drawerTarget.classList.contains("on")
  }
}
