module SpreeStripe
  class PaymentMethodsWebhookKey < Base
    self.table_name = 'payment_methods_webhook_keys'

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :webhook_key, class_name: 'SpreeStripe::WebhookKey'

    validates :payment_method, presence: true, uniqueness: { scope: :webhook_key_id }
  end
end
