module SpreeStripe
  class CompleteOrderFromSessionJob < BaseJob
    def perform(payment_session_id)
      payment_session = Spree::PaymentSessions::Stripe.find(payment_session_id)

      # PaymentSessions::Stripe duck-types as PaymentIntent
      SpreeStripe::CompleteOrder.new(payment_intent: payment_session).call

      payment_session.complete unless payment_session.completed?
    end
  end
end
