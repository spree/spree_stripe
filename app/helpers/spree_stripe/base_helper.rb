module SpreeStripe
  module BaseHelper
    def current_stripe_gateway
      @current_stripe_gateway ||= current_store.stripe_gateway
    end

    def current_stripe_payment_intent
      return if current_stripe_gateway.nil?

      @current_stripe_payment_intent ||= SpreeStripe::CreatePaymentIntent.new.call(@order, current_stripe_gateway)
    end
  end
end
