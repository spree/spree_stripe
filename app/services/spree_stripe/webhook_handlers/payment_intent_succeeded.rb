module SpreeStripe
  module WebhookHandlers
    class PaymentIntentSucceeded
      def call(event)
        payment_intent_data = event.data.object
        payment_intent = SpreeStripe::PaymentIntent.find_by!(stripe_id: payment_intent_data[:id])
        return if payment_intent.nil?

        SpreeStripe::CompleteOrderJob.set(wait: 10.seconds).perform_later(payment_intent.id)
      end
    end
  end
end
