module Spree
  module V2
    module Storefront
      module SpreeStripe
        module UserSerializerDecorator
          def self.prepended(base)
            base.attributes :stripe_customer_id do |user|
              user.stripe_customers.last.try(:profile_id)
            end
          end
        end
      end

      UserSerializer.prepend(SpreeStripe::UserSerializerDecorator)
    end
  end
end
