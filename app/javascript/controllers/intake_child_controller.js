import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["remove", "name", "heading"]
  static values = { saved: Boolean }

  rename() {
    this.headingTarget.textContent = this.nameTarget.value.trim()
  }

  // A saved child is only marked here. Nothing is removed until the step is saved.
  remove() {
    if (!this.savedValue) return this.element.remove()

    const name = this.nameTarget.value.trim() || "this child"
    if (!window.confirm(`Remove ${name} and their list?`)) return

    this.removeTarget.value = "1"
    this.element.hidden = true
  }
}
