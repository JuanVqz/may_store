import { Controller } from "@hotwired/stimulus"

// Live difference for the cash count.
//
// The server recomputes difference_cents in a before_save, so this is only about
// the admin seeing the shortfall while they count rather than after they submit.
// Money is handled in integer cents here for the same reason it is in the
// database: 0.1 + 0.2 in floats is not 0.3, and a one-cent phantom difference in
// a cash count is exactly the kind of thing someone would go looking for.
export default class extends Controller {
  static targets = ["row", "expected", "actual", "difference", "totalActual", "totalDifference"]

  connect() {
    this.recalc()
  }

  recalc() {
    let totalExpected = 0
    let totalActual = 0

    this.rowTargets.forEach((row) => {
      const expected = Number(row.querySelector("[data-expected]").dataset.expected)
      // The counted field specifically: the row's first input is the hidden id
      // of the nested record, and reading that gave the record id as pesos.
      const actual = this.centsFrom(row.querySelector("[data-cash-closing-target~='actual']"))

      totalExpected += expected
      totalActual += actual

      this.render(row.querySelector("[data-cash-closing-target~='difference']"), actual - expected, true)
    })

    if (this.hasTotalActualTarget) this.render(this.totalActualTarget, totalActual, false)
    if (this.hasTotalDifferenceTarget) this.render(this.totalDifferenceTarget, totalActual - totalExpected, true)
  }

  // Rounded rather than truncated: "12.005" typed into the field is 1201 cents,
  // not 1200, matching what Ruby's PriceCents setter does server-side.
  centsFrom(input) {
    if (!input || input.value === "") return 0

    const pesos = Number.parseFloat(input.value)
    return Number.isNaN(pesos) ? 0 : Math.round(pesos * 100)
  }

  render(element, cents, signed) {
    if (!element) return

    const amount = (Math.abs(cents) / 100).toFixed(2)
    const sign = signed && cents !== 0 ? (cents < 0 ? "-" : "+") : ""

    element.textContent = `${sign}$${amount}`
    element.className = element.className.replace(/\s*text-(destructive|green-700|muted-foreground)/g, "")

    if (!signed) return

    if (cents < 0) element.classList.add("text-destructive")
    else if (cents > 0) element.classList.add("text-green-700")
    else element.classList.add("text-muted-foreground")
  }
}
