module SpreeStripe
  module BaseHelper
    def current_stripe_gateway
      @current_stripe_gateway ||= current_store.stripe_gateway
    end

    # Server-side payment session for the current order, used for the legacy
    # Rails storefront payment flow: reuses the order's pending Stripe
    # session (keeping its amount in sync) or creates one. Memoized per request.
    # @return [Spree::PaymentSessions::Stripe, nil]
    def current_stripe_payment_session
      return if current_stripe_gateway.nil?

      @current_stripe_payment_session ||= SpreeStripe::CreatePaymentSession.new.call(@order, current_stripe_gateway)
    end

    # The cart-prefixed id the v3 Store API addresses carts by (e.g. `cart_xxx`).
    # Must match Spree::Api::V3::CartSerializer's encoding exactly.
    # @return [String]
    def stripe_cart_prefixed_id(order)
      "cart_#{Spree::PrefixedId::SQIDS.encode([order.id])}"
    end

    # The store's publishable Spree API key, used by the storefront JS as the
    # `X-Spree-API-Key` header for v3 Store API calls.
    # @return [String, nil]
    def current_store_publishable_api_key
      current_store.api_keys.publishable.active.first&.plaintext_token
    end
  end
end
