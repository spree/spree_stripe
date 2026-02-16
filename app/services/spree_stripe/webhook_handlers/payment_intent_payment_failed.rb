module SpreeStripe
  module WebhookHandlers
    class PaymentIntentPaymentFailed
      def call(event)
        stripe_id = event.data.object.id

        # New system: PaymentSession
        payment_session = Spree::PaymentSessions::Stripe.find_by(external_id: stripe_id)
        if payment_session.present?
          payment_session.fail if payment_session.can_fail?
          order = payment_session.order
          order.cancel! if !order.canceled? && order.can_cancel?
          return
        end

        # Legacy system: PaymentIntent
        payment_intent = SpreeStripe::PaymentIntent.find_by(stripe_id: stripe_id)
        return if payment_intent.nil?

        order = payment_intent.order
        return if order.canceled?

        order.cancel! if order.can_cancel?
      end
    end
  end
end
