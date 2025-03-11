module SpreeStripe
  class PaymentMethodsWebhookKey < Base
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :webhook_key, class_name: 'SpreeStripe::WebhookKey'

    validates :payment_method, presence: true, uniqueness: { scope: :webhook_key_id }
  end
end
