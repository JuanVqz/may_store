import { Controller } from "@hotwired/stimulus"

// Handles product customization: radio button styling, extras +/- buttons, live price calc
export default class extends Controller {
  static targets = ["totalPrice", "extraQuantity"]
  static values = { basePrice: Number }

  connect() {
    this.recalculate()
  }

  selectPortion(event) {
    const button = event.currentTarget
    const group = button.closest("[data-portion-group]")

    // Update radio
    const radio = button.querySelector("input[type=radio]")
    radio.checked = true

    // Update visual state
    group.querySelectorAll("label.btn").forEach(label => {
      label.classList.remove("btn-primary")
      label.classList.add("btn-outline")
    })
    button.classList.remove("btn-outline")
    button.classList.add("btn-primary")
  }

  increment(event) {
    const input = event.currentTarget.closest("[data-extra-row]").querySelector("input[type=number]")
    const max = parseInt(input.max) || 10
    if (parseInt(input.value) < max) {
      input.value = parseInt(input.value) + 1
      this.recalculate()
    }
  }

  decrement(event) {
    const input = event.currentTarget.closest("[data-extra-row]").querySelector("input[type=number]")
    if (parseInt(input.value) > 0) {
      input.value = parseInt(input.value) - 1
      this.recalculate()
    }
  }

  recalculate() {
    let total = this.basePriceValue

    this.extraQuantityTargets.forEach(input => {
      const unitPrice = parseInt(input.dataset.unitPrice) || 0
      total += parseInt(input.value) * unitPrice
    })

    this.totalPriceTarget.textContent = "$" + (total / 100).toFixed(2)
  }
}
