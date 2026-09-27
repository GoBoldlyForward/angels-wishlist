import { Controller } from "@hotwired/stimulus"

// Adds and removes Love Box groups on the event form. A removed group is
// simply not submitted, because saving replaces the whole list.
export default class extends Controller {
  static targets = ["list", "template", "group"]

  add() {
    const fields = this.templateTarget.innerHTML.replaceAll("NEW_GROUP", Date.now().toString())
    this.listTarget.insertAdjacentHTML("beforeend", fields)
    this.groupTargets.at(-1).querySelector("input[type=text]").focus()
  }

  remove(event) {
    event.target.closest("[data-admin-love-box-target='group']").remove()
  }
}
