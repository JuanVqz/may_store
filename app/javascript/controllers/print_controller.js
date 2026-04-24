import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  print(event) {
    event.preventDefault()
    window.print()
  }

  printOrder(event) {
    event.preventDefault()
    const order = event.target.closest("[data-kitchen-order]")
    if (!order) return
    order.setAttribute("data-printing", "")
    window.print()
    order.removeAttribute("data-printing")
  }
}
