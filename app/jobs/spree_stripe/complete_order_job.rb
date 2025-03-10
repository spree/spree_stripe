module SpreeStripe
  class CompleteOrderJob < BaseJob
    def perform(payment_intent_id)
      payment_intent = SpreeStripe::PaymentIntent.find(payment_intent_id)
      SpreeStripe::CompleteOrder.new(payment_intent: payment_intent).call
    end
  end
end
