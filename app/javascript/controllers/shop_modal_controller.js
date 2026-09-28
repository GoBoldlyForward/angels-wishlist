import { Controller } from "@hotwired/stimulus"
import { keepFocusInside, giveFocusBack } from "controllers/shop_focus"

// Product and child views load into a Turbo Frame and show as a dialog.
// Each is also a page of its own, which is what the link opens without JavaScript.
export default class extends Controller {
  static targets = [ "dialog", "frame", "close" ]

  remember(event) {
    const link = event.target.closest("a[data-turbo-frame='modal']")
    if (link && !this.isOpen) this.returnTo = link
  }

  open() {
    this.dialogTarget.hidden = false
    this.dialogTarget.classList.add("on")
    document.body.classList.add("has-dialog")
    if (this.hasCloseTarget) this.closeTarget.focus()
  }

  close() {
    if (!this.isOpen) return

    this.dialogTarget.classList.remove("on")
    this.dialogTarget.hidden = true
    document.body.classList.remove("has-dialog")
    this.frameTarget.removeAttribute("src")
    this.frameTarget.replaceChildren()
    giveFocusBack(this.returnTo)
  }

  keepFocus(event) {
    keepFocusInside(this.dialogTarget, event)
  }

  get isOpen() {
    return this.dialogTarget.classList.contains("on")
  }
}
