import { Controller } from "@hotwired/stimulus"

// Manages the single-page order flow: toggling product browser and inline customization
export default class extends Controller {
  async toggleCustomization(event) {
    const button = event.currentTarget
    const productId = button.dataset.productId
    const container = document.getElementById(`customization_product_${productId}`)

    // If already open, close it
    if (container.children.length > 0) {
      container.innerHTML = ""
      return
    }

    // Close any other open customization
    document.querySelectorAll("[id^='customization_product_']").forEach(el => {
      el.innerHTML = ""
    })

    // Fetch the customization form
    const response = await fetch(button.dataset.url, {
      headers: {
        "Accept": "text/html",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      }
    })

    if (response.ok) {
      container.innerHTML = await response.text()
    }
  }

  closeCustomization(event) {
    const container = event.currentTarget.closest(".customization-inline")?.parentElement
    if (container) {
      container.innerHTML = ""
    }
  }
}
