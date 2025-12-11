module SpreeStripe
  module WebhookHandlers
    class PaymentIntentPaymentFailed
      def call(event)
        payment_intent = SpreeStripe::PaymentIntent.find_by(stripe_id: event.data.object.id)
        return if payment_intent.nil?

        order = payment_intent.order
        return if order.canceled?

        order.cancel! if order.can_cancel?
      end
    end
  end
end
