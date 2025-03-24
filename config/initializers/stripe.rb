# for local setup you need to use Stripe-CLI and change the key manually
StripeEvent.signing_secret = ENV['STRIPE_SIGNING_SECRET'] if ENV['STRIPE_SIGNING_SECRET'].present?

Stripe.log_level = ENV.fetch('STRIPE_LOG_LEVEL', 'debug')
Stripe.api_version = '2023-10-16'
Stripe.set_app_info('Spree Stripe', version: Spree.version, url: 'https://spreecommerce.org')

Rails.application.config.after_initialize do
  StripeEvent.configure do |events|
    events.subscribe 'payment_intent.succeeded', SpreeStripe::WebhookHandlers::PaymentIntentSucceeded.new
    events.subscribe 'payment_intent.payment_failed', SpreeStripe::WebhookHandlers::PaymentIntentPaymentFailed.new
    events.subscribe 'setup_intent.succeeded', SpreeStripe::WebhookHandlers::SetupIntentSucceeded.new
  end
end
