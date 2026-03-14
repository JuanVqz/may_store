import { Controller } from "@hotwired/stimulus"

// Plays an audio beep when new items are appended to the kitchen queue.
// Listens for Turbo Stream append events on the connected element.
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
    if (stream.action === "append" && stream.target === "kitchen-queue") {
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
      oscillator.frequency.value = 800
      gain.gain.value = 0.3

      oscillator.start()
      oscillator.stop(ctx.currentTime + 0.2)

      oscillator.onended = () => ctx.close()
    } catch (_) {
      // Audio not available, silently ignore
    }
  }
}
