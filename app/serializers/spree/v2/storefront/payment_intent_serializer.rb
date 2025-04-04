module Spree
  module V2
    module Storefront
      class PaymentIntentSerializer < BaseSerializer
        set_type :payment_intent

        attributes :stripe_id, :client_secret, :ephemeral_key_secret, :customer_id, :amount, :stripe_payment_method_id

        belongs_to :order, serializer: Spree::V2::Storefront::OrderSerializer
        belongs_to :payment_method, serializer: Spree::V2::Storefront::PaymentMethodSerializer
        has_one :payment, serializer: Spree::V2::Storefront::PaymentSerializer
      end
    end
  end
end
