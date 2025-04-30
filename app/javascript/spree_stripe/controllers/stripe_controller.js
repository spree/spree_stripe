import { Controller } from '@hotwired/stimulus'
import showFlashMessage from 'spree/storefront/helpers/show_flash_message'

export default class extends Controller {
  static values = {
    apiKey: String,
    paymentIntent: Object,
    returnUrl: String,
    orderEmail: String,
    orderToken: String,
    colorPrimary: String,
    colorBackground: String,
    colorText: String,
    paymentIntentPath: String,
    checkoutPath: String,
    checkoutValidateOrderForPaymentPath: String
  }

  static targets = [
    'paymentElement',
    'loading',
    'spinner',
    'buttonText',
    'defaultCard'
  ]

  connect() {
    const stripeOptions = {}

    this.submitTarget = document.querySelector('#checkout-payment-submit')
    this.billingAddressCheckbox = document.querySelector('#order_use_shipping')
    this.billingAddressForm = document.querySelector('form.edit_order')
    this.stripe = Stripe(this.apiKeyValue, stripeOptions)

    if (this.hasDefaultCardTarget) {
      this.initializeStripe({
        target: { value: this.defaultCardTarget.value }
      })
    } else {
      this.initializeStripe({ target: { value: 'on' } })
    }

    // hijack the submit button to call the submit method
    this.submitTarget.addEventListener('click', this.submit.bind(this))
  }

  // Fetches a payment intent
  async initializeStripe(e) {
    this.setLoading(true)

    if (e.target.value == 'on') {
      this.stripePaymentMethodId = null
    } else {
      this.stripePaymentMethodId = e.target.value
    }

    const response = await fetch(
      `${this.paymentIntentPathValue}`,
      {
        method: 'PATCH',
        headers: this.spreeApiHeaders,
        body: JSON.stringify({
          payment_intent: {
            stripe_payment_method_id: this.stripePaymentMethodId
          }
        })
      }
    )
    const { data, error } = await response.json()

    if (error) {
      this.handleError(error)
      return
    }

    if (this.stripePaymentMethodId === null) {
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
        clientSecret: this.paymentIntentValue.client_secret
      })
      const paymentElement = this.elements.create('payment', {
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
      paymentElement.mount(this.paymentElementTarget)
      paymentElement.on('change', (event) => {
        this.selectedMethod = event.value?.type
      })
    }

    this.setLoading(false)
  }

  async submit(e) {
    e.preventDefault()
    this.setLoading(true)

    const validated = await this.validateOrderForPayment()

    if (!validated) {
      this.setLoading(false)
      e.stopImmediatePropagation()
      return
    }

    const billingAddress = await this.updateBillingAddress()

    if (!billingAddress) {
      this.setLoading(false)
      e.stopImmediatePropagation()
      return
    }

    if (this.stripePaymentMethodId) {
      const { paymentIntent, error } = await this.stripe.confirmCardPayment(
        this.paymentIntentValue.client_secret
      )

      this.handleError(error)

      window.location.href = this.returnUrlValue
    } else {
      const elements = this.elements

      if (!elements || !elements.getElement('payment')) {
        showFlashMessage(
          'An unexpected error occurred. Please refresh the page and try again.',
          'error'
        )
        return
      }

      const { error } = await this.stripe.confirmPayment({
        elements,
        confirmParams: {
          payment_method_data: {
            billing_details: {
              email: this.orderEmailValue,
              name: billingAddress.firstname + ' ' + billingAddress.lastname,
              address: {
                city: billingAddress.city,
                country: billingAddress.country_iso,
                line1: billingAddress.address1,
                line2: billingAddress.address2,
                postal_code: billingAddress.zipcode,
                state: billingAddress.state_code
              }
            }
          },
          return_url: this.returnUrlValue
        }
      })

      // This point will only be reached if there is an immediate error when
      // confirming the payment. Otherwise, your customer will be redirected to
      // your `return_url`. For some payment methods like iDEAL, your customer will
      // be redirected to an intermediate site first to authorize the payment, then
      // redirected to the `return_url`.
      // TODO: we need to remove the payment intent id from this order and create new
      this.handleError(error)
    }

    this.setLoading(false)
  }

  async validateOrderForPayment() {
    const response = await fetch(
      `${this.checkoutValidateOrderForPaymentPathValue}`,
      {
        method: 'POST',
        headers: this.spreeApiHeaders
      }
    )

    const json = await response.json()

    if (json.meta?.messages?.length) {
      const message = [
        json.meta.messages,
        'please refresh the page and try again.'
      ].join(', ')

      showFlashMessage(message, 'error')
      return false
    } else {
      return true
    }
  }

  async updateBillingAddress() {
    // billing address same as shipping address
    if (this.billingAddressCheckbox.checked) {
      const response = await fetch(`${this.checkoutPathValue}?include=billing_address`, {
        method: 'PATCH',
        headers: this.spreeApiHeaders,
        body: JSON.stringify({
          order: {
            use_shipping: true
          }
        })
      });

      const responseJson = await response.json();

      if (response.ok) {
        return responseJson.included.find(item => item.type === 'address').attributes;
      } else {
        this.submitTarget.disabled = false;
        return false;
      }
    }

    // billing address different from shipping address
    if (this.billingAddressForm.checkValidity()) {
      const formData = new FormData(this.billingAddressForm);

      const response = await fetch(`${this.checkoutPathValue}?include=billing_address`, {
        method: 'PATCH',
        headers: this.spreeApiHeaders,
        body: JSON.stringify({
          order: {
            bill_address_attributes: {
              firstname: formData.get("order[bill_address_attributes][firstname]"),
              lastname: formData.get("order[bill_address_attributes][lastname]"),
              address1: formData.get("order[bill_address_attributes][address1]"),
              address2: formData.get("order[bill_address_attributes][address2]"),
              city: formData.get("order[bill_address_attributes][city]"),
              country_id: formData.get("order[bill_address_attributes][country_id]"),
              state_id: formData.get("order[bill_address_attributes][state_id]"),
              state_name: formData.get("order[bill_address_attributes][state_name]"),
              zipcode: formData.get("order[bill_address_attributes][zipcode]"),
              phone: formData.get("order[bill_address_attributes][phone]")
            }
          }
        })
      });

      const responseJson = await response.json();

      if (response.ok) {
        return responseJson.included.find(item => item.type === 'address').attributes;
      } else {
        const errors = Array.isArray(responseJson.error) ? responseJson.error.join('. ') : responseJson.error || 'Billing address is invalid';
        showFlashMessage(errors, 'error');

        const flashMessage = document.getElementsByClassName('flash-message')[0];
        if (flashMessage) {
          flashMessage.scrollIntoView({ behavior: 'smooth', block: 'end', inline: 'nearest' });
        }

        this.submitTarget.disabled = false;
        return false;
      }
    } else {
      this.submitTarget.disabled = false;
      return false
    }
  }

  handleError(error) {
    if (error) {
      if (error.type === 'card_error' || error.type === 'validation_error') {
        showFlashMessage(error.message, 'error')
      } else {
        showFlashMessage(
          'An unexpected error occured. Please refresh the page and try again.',
          'error'
        )
      }

      this.submitTarget.disabled = false;

      window.scrollTo({
        top: 0,
        behavior: 'smooth'
      })
    }
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

  get spreeApiHeaders() {
    return {
      'X-Spree-Order-Token': this.orderTokenValue,
      'Content-Type': 'application/json'
    }
  }
}
