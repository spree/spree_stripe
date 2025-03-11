module Spree
  module V2
    module Storefront
      class PaymentIntentSerializer < BaseSerializer
        set_type :payment_intent

        attributes :stripe_id, :client_secret, :ephemeral_key_secret, :customer_id, :amount, :stripe_payment_method_id
      end
    end
  end
end
