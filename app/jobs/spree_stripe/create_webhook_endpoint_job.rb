module SpreeStripe
  class CreateWebhookEndpointJob < BaseJob
    def perform(payment_method_id)
      Spree::PaymentMethod.find(payment_method_id).create_webhook_endpoint
    end
  end
end
