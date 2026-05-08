module SpreeStripe
  module WebhookHandlers
    # Fires when a manual-capture PaymentIntent transitions to `requires_capture`
    # (i.e. the funds have been authorized but not yet captured). For new
    # PaymentSession-based flows we hand off to CompleteOrderFromSessionJob,
    # which authorizes the Spree::Payment and completes the order.
    class PaymentIntentAmountCapturableUpdated
      def call(event)
        stripe_id = event.data.object[:id]

        payment_session = Spree::PaymentSessions::Stripe.find_by(external_id: stripe_id)
        return if payment_session.nil?

        SpreeStripe::CompleteOrderFromSessionJob.set(wait: 10.seconds).perform_later(payment_session.id)
      end
    end
  end
end
