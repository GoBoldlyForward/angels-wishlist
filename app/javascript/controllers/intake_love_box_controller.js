import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["pick", "row", "count"]
  static values = { declined: String }

  toggle() {
    const pick = this.pickTarget.value
    const asks = pick !== "" && pick !== this.declinedValue

    this.rowTarget.hidden = !asks
    this.countTarget.value = ""
    this.countTarget.placeholder = pick.startsWith("One") ? "Number of caregivers" : "People in your home"
  }
}
