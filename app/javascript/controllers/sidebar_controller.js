import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar"
export default class extends Controller {
  static targets = ["sidebar"]

  toggle() {
    const sidebar = this.sidebarTarget

    if (sidebar.classList.contains("hidden")) {
      this.open()
    } else {
      this.close()
    }
  }

  open() {
    // Add backdrop first
    this.createBackdrop()

    // Remove hidden and add positioning classes
    this.sidebarTarget.classList.remove("hidden", "-translate-x-full")
    this.sidebarTarget.classList.add("fixed", "inset-y-0", "left-0", "z-40", "translate-x-0")

    // Force reflow to ensure transition happens
    this.sidebarTarget.offsetHeight
  }

  close() {
    // Slide out with animation
    this.sidebarTarget.classList.remove("translate-x-0")
    this.sidebarTarget.classList.add("-translate-x-full")

    // Remove backdrop
    this.removeBackdrop()

    // Hide after animation completes (300ms)
    setTimeout(() => {
      this.sidebarTarget.classList.add("hidden")
      this.sidebarTarget.classList.remove("fixed", "inset-y-0", "left-0", "z-40")
    }, 300)
  }

  createBackdrop() {
    const backdrop = document.createElement("div")
    backdrop.className = "fixed inset-0 bg-gray-600 bg-opacity-75 z-30 lg:hidden"
    backdrop.dataset.action = "click->sidebar#close"
    backdrop.id = "sidebar-backdrop"
    document.body.appendChild(backdrop)
  }

  removeBackdrop() {
    const backdrop = document.getElementById("sidebar-backdrop")
    if (backdrop) {
      backdrop.remove()
    }
  }
}
