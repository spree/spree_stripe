module StripeEvent
  module WebhookControllerDecorator
    def secrets(payload, signature)
      all_signing_keys = SpreeStripe::WebhookKey.pluck(:signing_secret).uniq.compact
      all_signing_keys << ENV['STRIPE_SIGNING_SECRET'] if ENV['STRIPE_SIGNING_SECRET'].present?

      return all_signing_keys if all_signing_keys.any?

      raise Stripe::SignatureVerificationError.new(
        'Cannot verify signature without a `StripeEvent.signing_secret`',
        signature, http_body: payload
      )
    end
  end

  WebhookController.prepend(WebhookControllerDecorator)
end
