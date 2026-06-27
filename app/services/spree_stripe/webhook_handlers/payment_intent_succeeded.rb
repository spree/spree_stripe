module SpreeStripe
  module WebhookHandlers
    class PaymentIntentSucceeded < Base
      def call(event)
        stripe_id = event.data.object[:id]

        enqueue_complete_order_from_session(stripe_id)
      end
    end
  end
end
