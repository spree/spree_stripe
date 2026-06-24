import { Controller } from '@hotwired/stimulus'
import showFlashMessage from 'spree/storefront/helpers/show_flash_message'

// Regular Stripe checkout on the v3 Store API — renders the payment form and
// confirms the payment. Completion is NOT handled here: both new and saved
// cards redirect to `return_url` (new cards via Stripe's redirect, saved cards
// manually after inline confirmation), where the server-side
// ConfirmPaymentsController finalizes the session + cart.
export default class extends Controller {
  static values = {
    apiKey: String,
    clientSecret: String,
    sessionId: String,
    cartId: String,
    cartToken: String,
    spreeApiKey: String,
    orderEmail: String,
    returnUrl: String,
    colorPrimary: String,
    colorText: String,
    paymentElementAdditionalOptions: { type: Object, default: {} }
  }

  static targets = ['paymentElement', 'loading', 'defaultCard']

  connect() {
    this.submitTarget = document.querySelector('#checkout-payment-submit')
    this.billingAddressCheckbox = document.querySelector('#order_use_shipping')
    this.billingAddressForm = document.querySelector('form.edit_order')
    this.stripe = Stripe(this.apiKeyValue)

    if (this.hasDefaultCardTarget) {
      this.initializeStripe({ target: { value: this.defaultCardTarget.value } })
    } else {
      this.initializeStripe({ target: { value: 'on' } })
    }

    if (this.submitTarget) {
      this.submitTarget.addEventListener('click', this.submit.bind(this))
    }
  }

  // Mounts the Payment Element for a new card, or records the selected saved card.
  initializeStripe(e) {
    this.setLoading(true)

    const value = e.target.value
    this.stripePaymentMethodId = value && value !== 'on' ? value : null

    if (this.stripePaymentMethodId === null && !this.elements) {
      const appearance = {
        theme: 'stripe',
        variables: {
          colorPrimary: this.colorPrimaryValue,
          colorText: this.colorTextValue
        }
      }
      this.elements = this.stripe.elements({ appearance, clientSecret: this.clientSecretValue })
      const paymentElement = this.elements.create('payment', {
        fields: {
          billingDetails: {
            name: 'never',
            email: 'never',
            address: { country: 'never', postalCode: 'never' }
          }
        },
        ...this.paymentElementAdditionalOptionsValue
      })
      paymentElement.mount(this.paymentElementTarget)
    }

    this.setLoading(false)
  }

  async submit(e) {
    e.preventDefault()
    this.setLoading(true)

    const billing = await this.updateBillingAddress()
    if (!billing) {
      this.setLoading(false)
      e.stopImmediatePropagation()
      return
    }

    if (this.stripePaymentMethodId) {
      // Saved card: bind it to the session, confirm inline, then hand off to the
      // return controller (mirrors how Stripe redirects new cards back).
      await this.patchSessionPaymentMethod(this.stripePaymentMethodId)

      const { error } = await this.stripe.confirmCardPayment(this.clientSecretValue, {
        payment_method: this.stripePaymentMethodId
      })

      if (error) {
        this.handleError(error)
        this.setLoading(false)
        return
      }

      window.location.href = this.returnUrlValue
    } else {
      // New card: confirm with the Payment Element; Stripe redirects to return_url.
      const elements = this.elements
      if (!elements || !elements.getElement('payment')) {
        showFlashMessage('An unexpected error occurred. Please refresh the page and try again.', 'error')
        this.setLoading(false)
        return
      }

      const { error } = await this.stripe.confirmPayment({
        elements,
        confirmParams: {
          return_url: this.returnUrlValue,
          payment_method_data: { billing_details: this.billingDetails(billing) }
        }
      })

      // Reached only on an immediate error; otherwise Stripe redirects to return_url.
      if (error) this.handleError(error)
      this.setLoading(false)
    }
  }

  // Persists the billing address to the cart via the v3 Store API.
  // Returns the cart's billing_address on success, false on failure.
  async updateBillingAddress() {
    let body
    if (this.billingAddressCheckbox?.checked) {
      body = { use_shipping: true }
    } else if (this.billingAddressForm?.checkValidity()) {
      body = { billing_address: this.readBillingAddressForm() }
    } else {
      if (this.submitTarget) this.submitTarget.disabled = false
      return false
    }

    const response = await fetch(this.cartApiBase, {
      method: 'PATCH',
      headers: this.spreeApiHeaders,
      body: JSON.stringify(body)
    })
    const json = await response.json().catch(() => ({}))

    if (response.ok) {
      return json.billing_address || {}
    }

    showFlashMessage(this.extractErrors(json) || 'Billing address is invalid', 'error')
    if (this.submitTarget) this.submitTarget.disabled = false
    return false
  }

  readBillingAddressForm() {
    const form = this.billingAddressForm
    const field = (name) => form.querySelector(`[name="order[bill_address_attributes][${name}]"]`)
    const value = (name) => field(name)?.value || null

    const countryOption = field('country_id')?.selectedOptions?.[0]
    const stateOption = field('state_id')?.selectedOptions?.[0]

    return {
      first_name: value('firstname'),
      last_name: value('lastname'),
      address1: value('address1'),
      address2: value('address2'),
      city: value('city'),
      postal_code: value('zipcode'),
      phone: value('phone'),
      country_iso: countryOption?.dataset?.iso || null,
      state_name: stateOption?.text?.trim() || value('state_name')
    }
  }

  billingDetails(address) {
    return {
      name: [address.first_name, address.last_name].filter(Boolean).join(' '),
      email: this.orderEmailValue,
      address: {
        city: address.city,
        country: address.country_iso,
        line1: address.address1,
        line2: address.address2,
        postal_code: address.postal_code,
        state: address.state_abbr || address.state_name
      }
    }
  }

  // Binds the selected saved card's payment method to the session server-side.
  async patchSessionPaymentMethod(stripePaymentMethodId) {
    await fetch(`${this.cartApiBase}/payment_sessions/${this.sessionIdValue}`, {
      method: 'PATCH',
      headers: this.spreeApiHeaders,
      body: JSON.stringify({ external_data: { stripe_payment_method_id: stripePaymentMethodId } })
    }).catch(() => {})
  }

  handleError(error) {
    if (!error) return

    // Per Stripe: only card_error / validation_error messages are meant to be
    // shown to customers; other types are developer-facing, so fall back to a
    // generic message.
    if (error.type === 'card_error' || error.type === 'validation_error') {
      showFlashMessage(error.message, 'error')
    } else {
      showFlashMessage('An unexpected error occurred. Please refresh the page and try again.', 'error')
    }

    if (this.submitTarget) this.submitTarget.disabled = false
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  setLoading(isLoading) {
    if (isLoading) {
      if (this.submitTarget) this.submitTarget.disabled = true
    } else {
      if (this.hasLoadingTarget) this.loadingTarget.classList.add('hidden')
      if (this.submitTarget) {
        this.submitTarget.disabled = false
        this.submitTarget.classList.remove('hidden')
      }
    }
  }

  extractErrors(json) {
    if (!json) return null
    if (typeof json.error === 'string') return json.error
    if (Array.isArray(json.error)) return json.error.join('. ')
    if (json.errors) {
      return Array.isArray(json.errors) ? json.errors.join('. ') : Object.values(json.errors).flat().join('. ')
    }
    return null
  }

  get cartApiBase() {
    return `/api/v3/store/carts/${this.cartIdValue}`
  }

  get spreeApiHeaders() {
    return {
      'X-Spree-API-Key': this.spreeApiKeyValue,
      'X-Spree-Token': this.cartTokenValue,
      'Content-Type': 'application/json'
    }
  }
}
