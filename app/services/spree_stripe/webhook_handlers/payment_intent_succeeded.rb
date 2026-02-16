module SpreeStripe
  module WebhookHandlers
    class PaymentIntentSucceeded
      def call(event)
        stripe_id = event.data.object[:id]

        # New system: PaymentSession
        payment_session = Spree::PaymentSessions::Stripe.find_by(external_id: stripe_id)
        if payment_session.present?
          SpreeStripe::CompleteOrderFromSessionJob.set(wait: 10.seconds).perform_later(payment_session.id)
          return
        end

        # Legacy system: PaymentIntent
        payment_intent = SpreeStripe::PaymentIntent.find_by(stripe_id: stripe_id)
        return if payment_intent.nil?

        SpreeStripe::CompleteOrderJob.set(wait: 10.seconds).perform_later(payment_intent.id)
      end
    end
  end
end
