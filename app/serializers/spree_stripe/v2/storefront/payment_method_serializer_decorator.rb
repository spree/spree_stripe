module SpreeStripe
  module V2
    module Storefront
      module PaymentMethodSerializerDecorator
        def self.prepended(base)
          base.attribute :publishable_key do |pm|
            pm.try(:preferred_publishable_key)
          end
        end
      end
    end
  end
end

if defined?(Spree::V2::Storefront::PaymentMethodSerializer)
  Spree::V2::Storefront::PaymentMethodSerializer.prepend(SpreeStripe::V2::Storefront::PaymentMethodSerializerDecorator)
end
