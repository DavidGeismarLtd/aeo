import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="confirmation"
export default class extends Controller {
  static values = {
    message: String
  }

  connect() {
    this.element.addEventListener("submit", this.confirm.bind(this))
  }

  confirm(event) {
    if (!window.confirm(this.messageValue || "Are you sure?")) {
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }

  disconnect() {
    this.element.removeEventListener("submit", this.confirm.bind(this))
  }
}

