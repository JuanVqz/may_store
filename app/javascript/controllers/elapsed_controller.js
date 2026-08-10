import { Controller } from "@hotwired/stimulus"

// Keeps a "waiting N min" label honest between Turbo refreshes.
//
// The kitchen queue only re-renders when a broadcast fires, so a server-rendered
// elapsed time freezes on a quiet kitchen. This recomputes it from the start
// timestamp on a fixed interval instead.
export default class extends Controller {
  static values = {
    start: String,
    template: String,
    interval: { type: Number, default: 30000 }
  }

  connect() {
    this.render()
    this.timer = setInterval(() => this.render(), this.intervalValue)
  }

  // A Turbo morph can swap the timestamp under a connected element.
  startValueChanged() {
    this.render()
  }

  disconnect() {
    clearInterval(this.timer)
  }

  render() {
    this.element.textContent = this.templateValue.replace("%{minutes}", this.minutes)
  }

  get minutes() {
    const elapsed = Date.now() - Date.parse(this.startValue)
    return Math.max(0, Math.floor(elapsed / 60000))
  }
}
