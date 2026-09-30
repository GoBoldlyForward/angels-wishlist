import { Controller } from "@hotwired/stimulus"

// One Love Box group: "No thank you" clears the other picks, checks stop at
// the group's limit, and the count field shows only for a pick that needs one.
export default class extends Controller {
  static targets = ["option", "row", "count"]
  static values = { declined: String, max: Number }

  connect() {
    this.cap()
  }

  toggle(event) {
    const input = event.target
    if (input.checked) {
      const declined = input.value === this.declinedValue
      this.optionTargets.forEach(other => {
        if (other !== input && (declined || other.value === this.declinedValue)) other.checked = false
      })
    }
    this.cap()
    this.askCount()
  }

  cap() {
    if (this.maxValue < 2) return

    const full = this.checked.length >= this.maxValue
    this.optionTargets.forEach(option => { option.disabled = full && !option.checked })
  }

  askCount() {
    if (!this.hasRowTarget) return

    const pick = this.checked[0]?.value || ""
    this.rowTarget.hidden = pick === "" || pick === this.declinedValue
    this.countTarget.value = ""
    this.countTarget.placeholder = pick.startsWith("One") ? "Number of caregivers" : "People in your home"
  }

  get checked() {
    return this.optionTargets.filter(option => option.checked)
  }
}
