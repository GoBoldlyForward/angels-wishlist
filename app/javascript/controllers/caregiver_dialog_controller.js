import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal"]

  open(event) {
    event.preventDefault()
    this.opener = event.currentTarget
    this.modalTarget.classList.add("on")
    this.modalTarget.querySelector(".x")?.focus()
  }

  close(event) {
    if (!this.modalTarget.classList.contains("on")) return

    event.preventDefault()
    this.modalTarget.classList.remove("on")
    this.opener?.focus()
  }
}
