import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "tag", "empty", "suggestion", "template"]
  static values = { name: String }

  connect() {
    this.commit = this.commit.bind(this)
    this.form = this.element.closest("form")
    this.form?.addEventListener("submit", this.commit)
  }

  disconnect() {
    this.form?.removeEventListener("submit", this.commit)
  }

  add(event) {
    event.preventDefault()
    this.commit()
  }

  suggest(event) {
    this.append(event.currentTarget.dataset.value)
    this.inputTarget.focus()
  }

  remove(event) {
    event.currentTarget.closest("[data-intake-tags-target='tag']").remove()
    this.refresh()
  }

  // Whatever is still typed in the box counts, so a caregiver who never
  // pressed enter does not lose it.
  commit() {
    this.append(this.inputTarget.value)
    this.inputTarget.value = ""
  }

  append(text) {
    const value = text.trim().toLowerCase()
    if (!value || this.chosen.includes(value)) return

    const tag = this.templateTarget.content.firstElementChild.cloneNode(true)
    tag.dataset.value = value
    tag.querySelector("input").name = this.nameValue
    tag.querySelector("input").value = value
    tag.querySelector("span").textContent = value
    tag.querySelector("button").setAttribute("aria-label", `Remove ${value}`)
    this.emptyTarget.before(tag)
    this.refresh()
  }

  refresh() {
    this.emptyTarget.hidden = this.tagTargets.length > 0
    this.suggestionTargets.forEach((chip) => {
      chip.hidden = this.chosen.includes(chip.dataset.value.toLowerCase())
    })
  }

  get chosen() {
    return this.tagTargets.map((tag) => tag.dataset.value)
  }
}
