import { Controller } from '@hotwired/stimulus'
import { loadStripe } from '@stripe/stripe-js/pure'
import showFlashMessage from 'spree/storefront/helpers/show_flash_message'

// Stripe zero-decimal currencies — amount is already in the smallest unit.
// https://docs.stripe.com/currencies#zero-decimal
const ZERO_DECIMAL_CURRENCIES = new Set([
  'bif', 'clp', 'djf', 'gnf', 'jpy', 'kmf', 'krw', 'mga', 'pyg',
  'rwf', 'ugx', 'vnd', 'vuv', 'xaf', 'xof', 'xpf'
])

// Apple Pay / Google Pay express checkout on the v3 Store API. The wallet sheet
// drives address + shipping selection against `/api/v3/store/carts`, then a
// payment session is created and confirmed; completion is handled server-side by
// ConfirmPaymentsController via the `return_url` (same as the regular flow).
export default class extends Controller {
  static values = {
    apiKey: String,
    spreeApiKey: String,
    paymentMethodId: String,
    cartId: String,
    cartToken: String,
    confirmPaymentUrl: String,
    currency: String,
    amount: Number,
    borderRadius: Number,
    height: Number,
    theme: String,
    maxRows: Number,
    maxColumns: Number,
    buttonWidth: Number,
    shippingRequired: { type: Boolean, default: true },
    phoneRequired: { type: Boolean, default: false }
  }

  static targets = ['container']

  connect() {
    this.isGooglePay = false
    this.shippingRateMap = new Map()
    this.initStripe()
  }

  initStripe() {
    if (typeof Stripe === 'undefined') {
      loadStripe(this.apiKeyValue).then((stripe) => {
        this.stripe = stripe
        this.prepareExpressCheckoutElement()
      })
    } else if (typeof this.stripe !== 'function') {
      this.stripe = Stripe(this.apiKeyValue)
      this.prepareExpressCheckoutElement()
    }
  }

  prepareExpressCheckoutElement() {
    this.elements = this.stripe.elements({
      mode: 'payment',
      currency: this.currencyValue,
      amount: parseInt(this.amountValue),
      appearance: {
        theme: 'stripe',
        variables: {
          borderRadius: this.hasBorderRadiusValue ? `${this.borderRadiusValue}px` : undefined
        }
      },
      paymentMethodCreation: 'manual'
    })

    const expressCheckout = this.elements.create('expressCheckout', {
      buttonHeight: this.heightValue > 0 ? this.heightValue : undefined,
      buttonTheme: {
        applePay: this.themeValue.length ? this.themeValue : undefined,
        googlePay: this.themeValue.length ? this.themeValue : undefined
      },
      layout: {
        overflow: this.maxRowsValue > 0 ? 'auto' : 'never',
        maxColumns: this.maxColumnsValue > 0 ? this.maxColumnsValue : undefined,
        maxRows: this.maxRowsValue > 0 ? this.maxRowsValue : undefined
      },
      buttonType: {
        applePay: 'check-out',
        googlePay: 'checkout'
      },
      paymentMethodOrder: ['applePay', 'googlePay', 'link']
    })
    expressCheckout.mount('#payment-request-button')

    expressCheckout.on('ready', this.handleReady.bind(this))
    expressCheckout.on('click', this.handleClick.bind(this))
    if (this.shippingRequiredValue) {
      expressCheckout.on('shippingaddresschange', this.handleAddressChange.bind(this))
      expressCheckout.on('shippingratechange', this.handleShippingOptionChange.bind(this))
    }
    expressCheckout.on('confirm', this.handleFinalizePayment.bind(this))
  }

  handleReady({ availablePaymentMethods }) {
    if (!availablePaymentMethods) {
      this.containerTarget.style.display = 'none'
      return
    }
    const availableMethodsCount = Object.keys(availablePaymentMethods).filter(
      (key) => availablePaymentMethods[key]
    ).length
    if (this.buttonWidthValue > 0) {
      this.containerTarget.style.setProperty('--desktop-max-width', this.buttonWidthValue * availableMethodsCount + 'px')
      this.containerTarget.classList.add('desktop-max-width')
    }
    window.parent?.postMessage({ enabledPaymentMethodsCount: availableMethodsCount }, '*')
  }

  handleClick(event) {
    this.isGooglePay = event.expressPaymentType === 'google_pay'
    event.resolve({
      emailRequired: true,
      phoneNumberRequired: this.phoneRequiredValue,
      shippingAddressRequired: this.shippingRequiredValue,
      lineItems: [{ name: 'Subtotal', amount: parseInt(this.amountValue) }]
    })
  }

  async handleAddressChange(event) {
    try {
      const { address } = event
      // Stripe only shares city/zip/country/state at this stage; pad the rest
      // with placeholders and quick_checkout to skip street-level validation.
      const cart = await this.patchCart({
        shipping_address: {
          first_name: 'Express',
          last_name: 'Checkout',
          address1: 'TBD',
          city: address.city,
          postal_code: address.postal_code,
          country_iso: address.country,
          state_name: address.state || undefined,
          quick_checkout: true
        }
      })
      if (!cart) return event.reject()

      const { shippingRates, selectionMap } = this.buildShippingRates(cart.fulfillments || [])
      this.shippingRateMap = selectionMap

      if (shippingRates.length === 0) return event.reject()

      const lineItems = this.buildLineItems(cart)
      lineItems.push({ name: 'Shipping', amount: shippingRates[0].amount })

      // Amount must be updated before resolve — Stripe requires amount >= sum(lineItems).
      this.elements.update({ amount: this.sumLineItems(lineItems) })
      event.resolve({ shippingRates, lineItems })
    } catch (_e) {
      try { event.reject() } catch (_) { /* already resolved */ }
    }
  }

  async handleShippingOptionChange(event) {
    try {
      const selections = this.shippingRateMap.get(event.shippingRate.id)
      if (!selections || selections.length === 0) return event.reject()

      let cart = null
      for (const { fulfillmentId, rateId } of selections) {
        cart = await this.patchFulfillment(fulfillmentId, rateId)
        if (!cart) return event.reject()
      }

      const lineItems = this.buildLineItems(cart)
      lineItems.push({ name: 'Shipping', amount: event.shippingRate.amount })

      this.elements.update({ amount: this.sumLineItems(lineItems) })
      event.resolve({ lineItems })
    } catch (_e) {
      try { event.reject() } catch (_) { /* already resolved */ }
    }
  }

  async handleFinalizePayment(event) {
    if (!this.stripe || !this.elements) {
      event.paymentFailed({ reason: 'fail' })
      return
    }

    const billing = event.billingDetails
    const shipping = event.shippingAddress
    const shipAddress = shipping?.address || billing?.address
    const billAddress = billing?.address || shipping?.address

    if (!shipAddress || !billAddress) {
      event.paymentFailed({ reason: 'invalid_shipping_address' })
      return
    }

    const phone = billing?.phone
    const shipName = this.parseName(shipping?.name || billing?.name || '')
    const billName = this.parseName(billing?.name || shipping?.name || '')

    // Persist the final email + addresses before creating the payment session.
    const cart = await this.patchCart({
      email: billing?.email,
      shipping_address: this.buildAddress(shipName, shipAddress, phone),
      billing_address: this.buildAddress(billName, billAddress, phone)
    })
    if (!cart) {
      event.paymentFailed({ reason: 'invalid_shipping_address' })
      return
    }

    // The wallet can keep stale rates and an enabled Pay button after a rejected
    // address change, so re-check the confirmed address is serviceable before
    // charging — otherwise the payment confirms but the order can't complete.
    if (this.shippingRequiredValue && !this.hasAvailableShipping(cart)) {
      event.paymentFailed({ reason: 'address_unserviceable' })
      return
    }

    const { error: submitError } = await this.elements.submit()
    if (submitError) {
      event.paymentFailed({ reason: 'fail' })
      this.handleError(submitError)
      return
    }

    const { error: pmError, paymentMethod } = await this.stripe.createPaymentMethod({ elements: this.elements })
    if (pmError || !paymentMethod) {
      event.paymentFailed({ reason: 'invalid_payment_data' })
      this.handleError(pmError)
      return
    }

    const session = await this.createPaymentSession(paymentMethod.id)
    const clientSecret = session?.external_data?.client_secret
    if (!clientSecret) {
      event.paymentFailed({ reason: 'fail' })
      return
    }

    const returnUrl = `${this.confirmPaymentUrlValue}?session=${session.id}`
    const { error: confirmError } = await this.stripe.confirmPayment({
      clientSecret,
      confirmParams: {
        payment_method: paymentMethod.id,
        return_url: returnUrl
      },
      redirect: 'if_required'
    })

    if (confirmError) {
      event.paymentFailed({ reason: 'fail' })
      this.handleError(confirmError)
      return
    }

    // Payment confirmed — let the server finalize the session + cart.
    window.location.href = returnUrl
  }

  // --- v3 Store API calls -------------------------------------------------

  async patchCart(body) {
    const response = await fetch(this.cartApiBase, {
      method: 'PATCH',
      headers: this.spreeApiHeaders,
      body: JSON.stringify(body)
    })
    return response.ok ? response.json() : null
  }

  async patchFulfillment(fulfillmentId, deliveryRateId) {
    const response = await fetch(`${this.cartApiBase}/fulfillments/${fulfillmentId}`, {
      method: 'PATCH',
      headers: this.spreeApiHeaders,
      body: JSON.stringify({ selected_delivery_rate_id: deliveryRateId })
    })
    return response.ok ? response.json() : null
  }

  async createPaymentSession(stripePaymentMethodId) {
    const response = await fetch(`${this.cartApiBase}/payment_sessions`, {
      method: 'POST',
      headers: this.spreeApiHeaders,
      body: JSON.stringify({
        payment_method_id: this.paymentMethodIdValue,
        external_data: { stripe_payment_method_id: stripePaymentMethodId }
      })
    })
    return response.ok ? response.json() : null
  }

  // --- helpers ------------------------------------------------------------

  // Line items for the wallet sheet. Shipping is added separately by the
  // address/rate handlers (Stripe owns shipping via shippingRates).
  buildLineItems(cart) {
    const items = [{ name: 'Subtotal', amount: this.toCents(cart.item_total) }]

    const discount = this.toCents(cart.discount_total)
    if (discount < 0) items.push({ name: 'Discount', amount: discount })

    const tax = this.toCents(cart.additional_tax_total)
    if (tax > 0) items.push({ name: 'Tax', amount: tax })

    return items
  }

  // Builds deduped Stripe shipping rates (by delivery_method_id) and a map from
  // each Stripe rate id to the per-fulfillment delivery rate ids to select.
  buildShippingRates(fulfillments) {
    const rateMap = new Map()
    const selectionMap = new Map()

    for (const fulfillment of fulfillments) {
      for (const rate of fulfillment.delivery_rates || []) {
        const methodId = rate.delivery_method_id

        if (!rateMap.has(methodId)) {
          // Google Pay rejects duplicate rate ids across address changes, so
          // give it a unique suffix.
          const id = this.isGooglePay ? `${methodId}-${this.randomSuffix()}` : String(methodId)
          rateMap.set(methodId, { id, displayName: rate.name, amount: this.toCents(rate.cost) })
          selectionMap.set(id, [])
        } else {
          rateMap.get(methodId).amount += this.toCents(rate.cost)
        }

        const stripeId = rateMap.get(methodId).id
        selectionMap.get(stripeId).push({ fulfillmentId: fulfillment.id, rateId: rate.id })
      }
    }

    return { shippingRates: Array.from(rateMap.values()), selectionMap }
  }

  // True when every shippable fulfillment has at least one delivery rate — i.e.
  // the confirmed address is serviceable. Digital fulfillments need no shipping.
  hasAvailableShipping(cart) {
    const shippable = (cart.fulfillments || []).filter((f) => f.fulfillment_type !== 'digital')
    return shippable.length > 0 && shippable.every((f) => (f.delivery_rates || []).length > 0)
  }

  buildAddress(name, address, phone) {
    return {
      first_name: name.firstName,
      last_name: name.lastName,
      address1: address.line1,
      address2: address.line2 || undefined,
      city: address.city,
      postal_code: address.postal_code,
      country_iso: address.country,
      state_name: address.state || undefined,
      phone: phone || undefined,
      quick_checkout: true
    }
  }

  parseName(name) {
    const parts = name.trim().split(/\s+/)
    if (parts.length <= 1) return { firstName: parts[0] || '', lastName: '' }
    return { firstName: parts.slice(0, -1).join(' '), lastName: parts[parts.length - 1] }
  }

  toCents(amount) {
    const n = Number(amount)
    if (!Number.isFinite(n)) return 0
    return ZERO_DECIMAL_CURRENCIES.has(this.currencyValue.toLowerCase()) ? Math.round(n) : Math.round(n * 100)
  }

  sumLineItems(lineItems) {
    return lineItems.reduce((sum, item) => sum + item.amount, 0)
  }

  randomSuffix() {
    return Math.random().toString(36).slice(2, 6)
  }

  handleError(error) {
    if (!error) return

    if (error.type === 'card_error' || error.type === 'validation_error') {
      showFlashMessage(error.message, 'error')
    } else {
      showFlashMessage('An unexpected error occurred. Please refresh the page and try again.', 'error')
    }
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
