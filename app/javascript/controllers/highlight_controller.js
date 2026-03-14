import { Controller } from "@hotwired/stimulus"

// Briefly highlights the element on connect (used for newly added items)
export default class extends Controller {
  connect() {
    this.element.classList.add("item-added")
    this.element.addEventListener("animationend", () => {
      this.element.classList.remove("item-added")
    }, { once: true })
  }
}
