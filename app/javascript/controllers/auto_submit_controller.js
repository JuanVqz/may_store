import { Controller } from "@hotwired/stimulus"

// Submits the form the moment a control changes, so a correction is one choice
// rather than a choice plus a save button.
//
// requestSubmit rather than submit, because submit skips validation and, more
// importantly here, skips the Turbo listener: submit() would take the whole page
// with it instead of letting Turbo handle the response.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
