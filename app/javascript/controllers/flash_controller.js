import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash messages after a delay
export default class extends Controller {
  static values = { delay: { type: Number, default: 4000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transition = "opacity 0.3s ease-out"
    this.element.style.opacity = "0"
    setTimeout(() => this.element.remove(), 300)
  }
}
