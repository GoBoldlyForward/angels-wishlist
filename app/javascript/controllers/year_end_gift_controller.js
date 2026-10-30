import { Controller } from "@hotwired/stimulus"

// Names the chosen amount on the button, and treats typing another amount as choosing it.
export default class extends Controller {
  static targets = [ "custom", "customChoice", "submit" ]

  connect() {
    this.refresh()
  }

  typed() {
    this.customChoiceTarget.checked = true
    this.refresh()
  }

  refresh() {
    const chosen = this.element.querySelector("input[name='amount']:checked")
    const dollars = chosen?.value === "custom" ? Number(this.customTarget.value) : Number(chosen?.value)
    const amount = dollars.toLocaleString("en-US", { style: "currency", currency: "USD", maximumFractionDigits: 0 })

    this.submitTarget.textContent = dollars > 0 ? `Add ${amount} to my donation` : "Add to my donation"
  }
}
