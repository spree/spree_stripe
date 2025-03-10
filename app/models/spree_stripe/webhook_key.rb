module SpreeStripe
  class WebhookKey < Base
    validates :stripe_id, presence: true, uniqueness: true
    validates :signing_secret, presence: true, uniqueness: true

    has_many :payment_methods_webhook_keys, class_name: 'SpreeStripe::PaymentMethodsWebhookKey', dependent: :destroy
    has_many :payment_methods, through: :payment_methods_webhook_keys, class_name: 'Spree::PaymentMethod', dependent: :destroy

    enum :kind, { direct: 0, connect: 1 }

    if Rails.configuration.active_record.encryption.include?(:primary_key)
      encrypts :stripe_id, deterministic: true
      encrypts :signing_secret, deterministic: true
    end
  end
end
