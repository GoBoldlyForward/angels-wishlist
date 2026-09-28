import { Controller } from "@hotwired/stimulus"

// Sections are visible in the markup. Only one this has taken responsibility for is
// hidden, and the timer shows it anyway if the observer never fires.
export default class extends Controller {
  connect() {
    if (!("IntersectionObserver" in window)) return
    if (this.element.getBoundingClientRect().top < window.innerHeight) return

    this.element.classList.add("pending")
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) this.show()
    }, { rootMargin: "0px 0px -6% 0px" })
    this.observer.observe(this.element)
    this.failsafe = setTimeout(() => this.show(), 1400)
  }

  disconnect() {
    this.show()
  }

  show() {
    clearTimeout(this.failsafe)
    this.observer?.disconnect()
    this.element.classList.remove("pending")
  }
}
