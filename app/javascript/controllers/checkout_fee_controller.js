import { Controller } from "@hotwired/stimulus"

// Shows what the card will be charged as the donor turns the processing fee on and off.
export default class extends Controller {
  static targets = [ "choice", "total" ]
  static values = { total: Number, fee: Number }

  connect() {
    this.refresh()
  }

  refresh() {
    const cents = this.totalValue + (this.choiceTarget.checked ? this.feeValue : 0)
    const charged = (cents / 100).toLocaleString("en-US", { style: "currency", currency: "USD" })

    this.totalTargets.forEach((total) => { total.textContent = charged })
  }
}
