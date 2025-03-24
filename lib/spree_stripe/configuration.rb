module SpreeStripe
  class Configuration < Spree::Preferences::Configuration
    preference :supported_webhook_events, :array, default: %w[payment_intent.payment_failed payment_intent.succeeded setup_intent.succeeded]
  end
end
