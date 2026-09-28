import { Controller } from "@hotwired/stimulus"

// A quantity field with a running total. Prices are in cents, in the order the gifts will be funded.
export default class extends Controller {
  static targets = [ "quantity", "less", "more", "total", "count" ]
  static values = { prices: Array }

  connect() {
    this.lessTarget.hidden = false
    this.moreTarget.hidden = false
    this.refresh()
  }

  less() {
    this.change(-1)
  }

  more() {
    this.change(1)
  }

  change(step) {
    this.quantityTarget.value = this.chosen + step
    this.refresh()
  }

  refresh() {
    const chosen = this.chosen
    const cents = this.pricesValue.slice(0, chosen).reduce((sum, price) => sum + price, 0)

    if (this.quantityTarget.value !== "") this.quantityTarget.value = chosen
    this.totalTarget.textContent = `$${Math.round(cents / 100).toLocaleString("en-US")}`
    this.countTarget.textContent = chosen
    this.lessTarget.disabled = chosen <= 1
    this.moreTarget.disabled = chosen >= this.pricesValue.length
  }

  get chosen() {
    const typed = parseInt(this.quantityTarget.value, 10) || 1
    return Math.min(Math.max(typed, 1), this.pricesValue.length)
  }
}
