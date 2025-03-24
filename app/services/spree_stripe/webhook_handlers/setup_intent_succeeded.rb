module SpreeStripe
  module WebhookHandlers
    class SetupIntentSucceeded
      def call(event)
        setup_intent_data = event.data.object
        gateway_customer = Spree::GatewayCustomer.find_by(profile_id: setup_intent_data.customer)
        return if gateway_customer.nil?

        spree_payment_method = gateway_customer.payment_method

        user = gateway_customer.user
        return if user.nil?

        stripe_payment_method = Stripe::PaymentMethod.retrieve(
          setup_intent_data.payment_method,
          { api_key: spree_payment_method.preferred_secret_key }
        )

        SpreeStripe::CreateSource.new(
          payment_method_details: stripe_payment_method,
          payment_method_id: setup_intent_data.payment_method,
          billing_details: stripe_payment_method.billing_details,
          gateway: spree_payment_method,
          user: user
        ).call
      end
    end
  end
end
