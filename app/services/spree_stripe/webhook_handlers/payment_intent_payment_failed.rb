module SpreeStripe
  module WebhookHandlers
    class PaymentIntentPaymentFailed
      def call(event)
        stripe_id = event.data.object.id

        payment_session = Spree::PaymentSessions::Stripe.find_by(external_id: stripe_id)
        return if payment_session.blank?

        payment_session.fail if payment_session.can_fail?
        order = payment_session.order
        order.cancel! if !order.canceled? && order.can_cancel?
      end
    end
  end
end
