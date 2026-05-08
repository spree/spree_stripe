module SpreeStripe
  module WebhookHandlers
    class PaymentIntentSucceeded < Base
      def call(event)
        stripe_id = event.data.object[:id]

        return if enqueue_complete_order_from_session(stripe_id)

        # Legacy system: PaymentIntent
        payment_intent = SpreeStripe::PaymentIntent.find_by(stripe_id: stripe_id)
        return if payment_intent.nil?

        SpreeStripe::CompleteOrderJob.set(wait: ENQUEUE_DELAY).perform_later(payment_intent.id)
      end
    end
  end
end
