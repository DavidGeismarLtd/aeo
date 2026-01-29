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
    this.sidebarTarget.classList.remove("hidden")
    this.sidebarTarget.classList.add("fixed", "inset-0", "z-40", "lg:static", "lg:z-auto")

    // Add backdrop
    this.createBackdrop()
  }

  close() {
    this.sidebarTarget.classList.add("hidden")
    this.removeBackdrop()
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

