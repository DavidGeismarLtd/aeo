import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="form-validation"
export default class extends Controller {
  static targets = ["field", "submit", "imagePreview"]

  connect() {
    console.log("Form validation controller connected")
  }

  validate(event) {
    event.preventDefault()

    if (this.validateAllFields()) {
      event.target.submit()
    }
  }

  validateAllFields() {
    let isValid = true

    this.fieldTargets.forEach(field => {
      if (!this.validateField(field)) {
        isValid = false
      }
    })

    return isValid
  }

  validateField(field) {
    const rules = field.dataset.validationRules
    if (!rules) return true

    const value = field.value.trim()
    const ruleArray = rules.split("|")
    let isValid = true
    let errorMessage = ""

    ruleArray.forEach(rule => {
      const [ruleName, ruleValue] = rule.split(":")

      switch (ruleName) {
        case "required":
          if (value === "") {
            isValid = false
            errorMessage = "This field is required"
          }
          break

        case "min":
          if (value.length < parseInt(ruleValue)) {
            isValid = false
            errorMessage = `Must be at least ${ruleValue} characters`
          }
          break

        case "max":
          if (value.length > parseInt(ruleValue)) {
            isValid = false
            errorMessage = `Must be no more than ${ruleValue} characters`
          }
          break

        case "url":
          if (value !== "" && !this.isValidUrl(value)) {
            isValid = false
            errorMessage = "Must be a valid URL"
          }
          break

        case "email":
          if (value !== "" && !this.isValidEmail(value)) {
            isValid = false
            errorMessage = "Must be a valid email address"
          }
          break

        case "domain":
          if (value !== "" && !this.isValidDomain(value)) {
            isValid = false
            errorMessage = "Must be a valid domain name"
          }
          break
      }
    })

    this.updateFieldValidation(field, isValid, errorMessage)
    return isValid
  }

  updateFieldValidation(field, isValid, errorMessage) {
    const errorElement = field.parentElement.querySelector(".validation-error")

    if (isValid) {
      field.classList.remove("border-red-300", "focus:border-red-500", "focus:ring-red-500")
      field.classList.add("border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500")

      if (errorElement) {
        errorElement.remove()
      }
    } else {
      field.classList.remove("border-gray-300", "focus:border-indigo-500", "focus:ring-indigo-500")
      field.classList.add("border-red-300", "focus:border-red-500", "focus:ring-red-500")

      if (!errorElement) {
        const error = document.createElement("p")
        error.className = "mt-2 text-sm text-red-600 validation-error"
        error.textContent = errorMessage
        field.parentElement.appendChild(error)
      } else {
        errorElement.textContent = errorMessage
      }
    }
  }

  previewImage(event) {
    const url = event.target.value.trim()

    if (this.hasImagePreviewTarget && url && this.isValidUrl(url)) {
      const img = this.imagePreviewTarget.querySelector("img")
      img.src = url
      this.imagePreviewTarget.classList.remove("hidden")

      img.onerror = () => {
        this.imagePreviewTarget.classList.add("hidden")
      }
    } else if (this.hasImagePreviewTarget) {
      this.imagePreviewTarget.classList.add("hidden")
    }
  }

  isValidUrl(string) {
    try {
      const url = new URL(string)
      return url.protocol === "http:" || url.protocol === "https:"
    } catch (_) {
      return false
    }
  }

  isValidEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/
    return re.test(email)
  }

  isValidDomain(domain) {
    const re = /^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$/i
    return re.test(domain)
  }
}

