import { Controller } from "@hotwired/stimulus"

// Plays an audio beep when a line item is marked as ready on the order view.
// Listens for Turbo Stream replace events targeting line_item_* elements
// and checks if the new content contains the "ready" status.
export default class extends Controller {
  connect() {
    this.handleStream = this.#onBeforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.handleStream)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.handleStream)
  }

  #onBeforeStreamRender(event) {
    const stream = event.target
    if (stream.action !== "replace") return
    if (!stream.target?.startsWith("line_item_")) return

    const template = stream.querySelector("template")
    if (!template) return

    const newContent = template.content.querySelector("[data-status='ready']")
    if (newContent) {
      this.#playBeep()
    }
  }

  #playBeep() {
    try {
      const ctx = new (window.AudioContext || window.webkitAudioContext)()
      const oscillator = ctx.createOscillator()
      const gain = ctx.createGain()

      oscillator.connect(gain)
      gain.connect(ctx.destination)

      oscillator.type = "sine"
      oscillator.frequency.value = 600
      gain.gain.value = 0.3

      oscillator.start()
      oscillator.stop(ctx.currentTime + 0.2)

      oscillator.onended = () => ctx.close()
    } catch (_) {
      // Audio not available, silently ignore
    }
  }
}
