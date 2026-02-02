import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="flash"
export default class extends Controller {
  static targets = ["message", "progress"]

  connect() {
    this.messageTargets.forEach((message, index) => {
      // Stagger the appearance of multiple messages
      setTimeout(() => {
        this.show(message)
        this.startAutoDismiss(message, index)
      }, index * 100)
    })
  }

  show(message) {
    // Animate in
    message.classList.add("translate-x-0", "opacity-100")
    message.classList.remove("translate-x-full", "opacity-0")
  }

  startAutoDismiss(message, index) {
    const progressBar = this.progressTargets[index]

    // Start progress bar animation
    setTimeout(() => {
      progressBar.style.width = "0%"
    }, 100)

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      this.dismissMessage(message)
    }, 5000)
  }

  dismiss(event) {
    const message = event.currentTarget.closest('[data-flash-target="message"]')
    this.dismissMessage(message)
  }

  dismissMessage(message) {
    // Animate out
    message.classList.add("translate-x-full", "opacity-0")
    message.classList.remove("translate-x-0", "opacity-100")

    // Remove from DOM after animation
    setTimeout(() => {
      message.remove()
    }, 300)
  }
}

