module SpreeStripe
  module WebhookHandlers
    class Base
      # Delay before processing a webhook to give the storefront's own session-complete
      # request a chance to land first, avoiding double-processing of the same payment.
      ENQUEUE_DELAY = 10.seconds

      private

      def enqueue_complete_order_from_session(stripe_id)
        payment_session = Spree::PaymentSessions::Stripe.find_by(external_id: stripe_id)
        return nil if payment_session.nil?

        SpreeStripe::CompleteOrderFromSessionJob.set(wait: ENQUEUE_DELAY).perform_later(payment_session.id)
        payment_session
      end
    end
  end
end
