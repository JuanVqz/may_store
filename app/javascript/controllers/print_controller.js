import { Controller } from "@hotwired/stimulus"
import { isSupported, printUrl, PrinterError } from "lib/thermal_printer"

// Prints a receipt on the thermal printer over WebUSB.
//
// The server renders the receipt as ESC/POS bytes and this controller forwards
// them to the printer, so nothing is rendered and no print dialog opens. Where
// WebUSB is unavailable (Safari, Firefox) it falls back to window.print(), which
// prints the page itself through the OS.
//
// Messages are passed in from the view because all user-facing text comes from
// the locale files, and this file cannot reach I18n.
export default class extends Controller {
  static values = {
    messages: { type: Object, default: {} },
    // Development opens the receipt as text in a new tab rather than printing
    // it, so iterating on a layout costs no paper. See ApplicationHelper.
    preview: { type: Boolean, default: false }
  }

  async receipt(event) {
    await this.send(event, event.params.url)
  }

  // The kitchen queue renders one button per order, each carrying its own URL.
  async ticket(event) {
    await this.send(event, event.params.url)
  }

  async send(event, url) {
    event.preventDefault()

    if (this.previewValue) {
      window.open(`${url}.txt`, "_blank")
      return
    }

    if (!isSupported()) {
      this.fallbackToBrowserPrint()
      return
    }

    const button = event.currentTarget
    button.disabled = true

    try {
      await printUrl(url)
      this.clearError()
    } catch (error) {
      this.showError(error)
    } finally {
      button.disabled = false
    }
  }

  // Kept for the browsers WebUSB never reaches. The print stylesheet in
  // application.css is what makes this legible on an 80mm roll, and on the
  // kitchen screen it hides every order group except the one marked
  // [data-printing] — without the mark, the page prints blank.
  fallbackToBrowserPrint() {
    const group = this.element.closest("[data-kitchen-order]") ||
                  this.element.querySelector("[data-kitchen-order]")

    if (!group) {
      window.print()
      return
    }

    group.setAttribute("data-printing", "")
    const cleanUp = () => {
      group.removeAttribute("data-printing")
      window.removeEventListener("afterprint", cleanUp)
    }
    window.addEventListener("afterprint", cleanUp)
    window.print()
  }

  showError(error) {
    const reason = error instanceof PrinterError ? error.reason : "transfer_failed"
    const message = this.messagesValue[reason] || this.messagesValue.transfer_failed

    this.errorElement.textContent = message
    this.errorElement.hidden = false
  }

  clearError() {
    if (this.error) this.error.hidden = true
  }

  get errorElement() {
    if (!this.error) {
      this.error = document.createElement("p")
      this.error.setAttribute("role", "alert")
      this.error.className = "text-sm text-destructive mt-2"
      this.element.appendChild(this.error)
    }
    return this.error
  }
}
