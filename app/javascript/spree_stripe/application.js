import '@hotwired/turbo-rails'
import { Application } from '@hotwired/stimulus'

let application

if (typeof window.Stimulus === "undefined") {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}

import CheckoutStripeButtonController from 'spree_stripe/controllers/stripe_button_controller'
import CheckoutStripeController from 'spree_stripe/controllers/stripe_controller'

application.register('checkout-stripe-button', CheckoutStripeButtonController)
application.register('checkout-stripe', CheckoutStripeController)
