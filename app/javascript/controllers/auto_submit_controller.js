import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as a field changes. The submit button is only there
// for when this controller never connects, so it is hidden once it has.
export default class extends Controller {
  static targets = ["fallback"]

  connect() {
    this.fallbackTargets.forEach((button) => { button.hidden = true })
  }

  submit() {
    this.element.requestSubmit()
  }
}
