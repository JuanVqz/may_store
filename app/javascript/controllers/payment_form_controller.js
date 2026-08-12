import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["method", "received", "receivedInput", "change"]
  static values = { total: Number }

  connect() {
    this.update()
    // The field is autofocused and pre-filled with 0.00, so a cashier typing 5
    // to mean five pesos was landing next to the zeros and getting 50.00.
    // Selecting the content makes the first keystroke replace it.
    this.selectReceived()
  }

  // Also on focus, so coming back to the field by click or tab behaves the same
  // way as arriving on it.
  selectReceived() {
    this.receivedInputTarget.select()
  }

  update() {
    const cashChecked = this.methodTargets.some(
      (m) => m.checked && m.dataset.cash === "true"
    )
    const received = parseFloat(this.receivedInputTarget.value)

    // When switching to non-cash, pre-fill with total if empty
    if (!cashChecked && (isNaN(received) || received === 0)) {
      this.receivedInputTarget.value = this.totalValue.toFixed(2)
    }

    // Always show received field, but change label for non-cash
    this.receivedTarget.classList.remove("hidden")
    this.receivedInputTarget.required = true
    this.recalc()
  }

  recalc() {
    const received = parseFloat(this.receivedInputTarget.value)
    if (isNaN(received)) {
      this.changeTarget.textContent = ""
      return
    }
    const change = received - this.totalValue
    if (change < 0) {
      this.changeTarget.textContent = ""
      return
    }
    this.changeTarget.textContent = `$${change.toFixed(2)}`
  }
}
