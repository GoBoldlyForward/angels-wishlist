import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name"]

  reset(event) {
    if (!event.detail.success) return

    this.element.querySelectorAll("input:not([type='hidden'])").forEach((input) => { input.value = "" })
    this.nameTarget.focus()
  }
}
