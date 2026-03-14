import { Controller } from "@hotwired/stimulus"

// Toggles the empty state message in the kitchen queue based on child count.
// Observes DOM mutations to react to Turbo Stream appends/removes.
export default class extends Controller {
  static targets = ["empty"]

  connect() {
    this.observer = new MutationObserver(() => this.#toggle())
    this.observer.observe(this.element, { childList: true })
    this.#toggle()
  }

  disconnect() {
    this.observer.disconnect()
  }

  #toggle() {
    const hasItems = this.element.querySelectorAll(".kitchen-card").length > 0
    if (this.hasEmptyTarget) {
      this.emptyTarget.style.display = hasItems ? "none" : ""
    }
  }
}
