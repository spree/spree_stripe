module Spree
  module Api
    module V2
      module Storefront
        module Stripe
          class BaseController < ::Spree::Api::V2::BaseController
            before_action :require_stripe_gateway

            def require_stripe_gateway
              render_error_payload('Stripe gateway is not present') unless stripe_gateway
            end

            def stripe_gateway
              @stripe_gateway ||= current_store.stripe_gateway
            end
          end
        end
      end
    end
  end
end
