module SpreeStripe
  class CreatePaymentIntent
    def call(order, gateway, stripe_payment_method_id: nil, off_session: false)
      total = order.total_minus_store_credits
      amount = Spree::Money.new(total).cents

      return nil if amount.zero?

      # lookup in database for existing payment intent
      payment_intent = SpreeStripe::PaymentIntent.where(order: order, payment_method: gateway).last

      # We need to check if the payment intent is synchronized with our database payment
      needs_new_payment_intent = false

      if payment_intent.present?
        stripe_payment_intent_status = payment_intent.stripe_payment_intent&.status

        needs_new_payment_intent = true if SpreeStripe::PaymentIntent::BLOCKED_STATES.include?(stripe_payment_intent_status)
      end

      return payment_intent if payment_intent.present? && !needs_new_payment_intent

      # response is an ActiveMerchant::Billing::Response object
      # https://github.com/activemerchant/active_merchant/blob/master/lib/active_merchant/billing/response.rb
      response = gateway.create_payment_intent(
        amount,
        order,
        payment_method_id: stripe_payment_method_id,
        off_session: off_session
      )

      # we should only create a customer if the order was placed by a user
      customer = gateway.fetch_or_create_customer(user: order.user) if order.user.present?
      ephemeral_key_response = gateway.create_ephemeral_key(customer.profile_id) if customer.present?
      ephemeral_key_secret = ephemeral_key_response&.params['secret'] if ephemeral_key_response.present?

      # persist the payment intent
      SpreeStripe::PaymentIntent.create!(
        order: order,
        payment_method: gateway,
        amount: total,
        stripe_id: response.authorization,
        client_secret: response.params['client_secret'],
        customer_id: customer&.profile_id,
        stripe_payment_method_id: stripe_payment_method_id,
        ephemeral_key_secret: ephemeral_key_secret
      )
    end
  end
end
