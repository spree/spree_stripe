module SpreeStripe
  module PaymentMethodDecorator
    STRIPE_TYPE = 'SpreeStripe::Gateway'.freeze unless defined?(STRIPE_TYPE)

    def self.prepended(base)
      base.has_many :payment_methods_webhook_keys, class_name: 'SpreeStripe::PaymentMethodsWebhookKey'
      base.has_many :webhook_keys, through: :payment_methods_webhook_keys, class_name: 'SpreeStripe::WebhookKey'

      base.scope :stripe, -> { where(type: STRIPE_TYPE) }
    end

    def stripe?
      type == STRIPE_TYPE
    end
  end
end

Spree::PaymentMethod.prepend(SpreeStripe::PaymentMethodDecorator)
