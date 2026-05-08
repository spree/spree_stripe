module SpreeStripe
  module WebhookHandlers
    # Fires when a manual-capture PaymentIntent transitions to `requires_capture`
    # (i.e. the funds have been authorized but not yet captured). For new
    # PaymentSession-based flows we hand off to CompleteOrderFromSessionJob,
    # which authorizes the Spree::Payment and completes the order.
    class PaymentIntentAmountCapturableUpdated < Base
      def call(event)
        enqueue_complete_order_from_session(event.data.object[:id])
      end
    end
  end
end
