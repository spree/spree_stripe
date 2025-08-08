import { Controller } from '@hotwired/stimulus'
import showFlashMessage from 'spree/storefront/helpers/show_flash_message'

export default class extends Controller {

  static values = {
    apiKey: String,
    setupIntent: String,
    colorPrimary: String,
    colorBackground: String,
    colorText: String,
    returnUrl: String,
    userEmail: String,
    billingAddress: Object,
    country: String,
    state: String
  }

  static targets = [
    'setupElement'
  ]

  connect() {
    const stripeOptions = {}

    this.submitTarget = document.querySelector('#add-credit-card-button')

    this.stripe = Stripe(this.apiKeyValue, stripeOptions)

    this.initializeStripe({ target: { value: 'on' } })

    this.submitTarget.addEventListener('click', this.submit.bind(this))
  }

  async initializeStripe(e) {
    const appearance = {
      theme: 'stripe',
      variables: {
        colorPrimary: this.colorPrimaryValue,
        colorBackground: this.colorBackgroundValue,
        colorText: this.colorTextValue
      }
    }

    this.elements = this.stripe.elements({
      appearance,
      clientSecret: this.setupIntentValue
    })

    const setupElement = this.elements.create('payment', {
      fields: {
        billingDetails: {
          name: 'never',
          email: 'never',
          address: {
            country: 'never',
            postalCode: 'never'
          }
        }
      }
    })
    setupElement.mount(this.setupElementTarget)
    setupElement.on('change', (event) => {
      this.selectedMethod = event.value?.type
    })
  }

  handleError(error) {
    showFlashMessage(error.message, 'error')
  }

  async submit(e) {
    e.preventDefault()
    this.setLoading(true)

    this.stripe.confirmSetup({
      elements: this.elements,
      confirmParams: {
        return_url: this.returnUrlValue,
        payment_method_data: {
          billing_details: {
            name: this.billingAddressValue.first_name + ' ' + this.billingAddressValue.last_name,
            email: this.userEmailValue,
            address: {
              city: this.billingAddressValue.city,
              country: this.countryValue,
              line1: this.billingAddressValue.address1,
              line2: this.billingAddressValue.address2,
              postal_code: this.billingAddressValue.zipcode,
              state: this.stateValue
            }
          }
        }
      }
    }).then((result) => {
      if (result.error) {
        this.handleError(result.error)
        // window.location.href = this.returnUrlValue
      }
    })
  }

  // Show a spinner on payment submission
  setLoading(isLoading) {
    if (isLoading) {
      // Disable the button and show a spinner
      this.submitTarget.disabled = true
    } else {
      this.loadingTarget.classList.add('hidden')
      this.submitTarget.disabled = false
      this.submitTarget.classList.remove('hidden')
    }
  }
}

