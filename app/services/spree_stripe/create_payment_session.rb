module SpreeStripe
  # Reuses the order's pending Stripe payment session (keeping its amount in sync
  # with the order total) or creates a new one via the gateway. The v3 successor
  # to the legacy CreatePaymentIntent service.
  class CreatePaymentSession
    def call(order, gateway)
      amount = order.total_minus_store_credits
      return if Spree::Money.new(amount, currency: order.currency).cents.zero?

      session = order.payment_sessions.where(payment_method: gateway, status: 'pending').order(:created_at).last

      return gateway.create_payment_session(order: order) unless session

      gateway.update_payment_session(payment_session: session, amount: amount) if session.amount != amount
      session
    end
  end
end
