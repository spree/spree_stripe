module SpreeStripe
  module WebhookHandlers
    class PaymentIntentPaymentFailed
      def call(event)
        return unless ['affirm', 'afterpay_clearpay'].include?(event.data.object&.last_payment_error&.payment_method&.type)

        payment_intent = SpreeStripe::PaymentIntent.find_by(stripe_id: event.data.object.id)
        order = payment_intent.order

        return if order.canceled?

        order.cancel!
      end
    end
  end
end
