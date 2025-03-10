module SpreeStripe
  class CreateGatewayWebhooks
    def call(payment_method:, events: SpreeStripe::Gateway::DIRECT_ENABLED_EVENTS, connect: false)
      webhook_list = Stripe::WebhookEndpoint.list({}, { api_key: payment_method.preferred_secret_key })
      webhook = find_webhook(webhook_list[:data], events)

      ensure_webhook(payment_method, webhook, connect, events)
    end

    private

    def find_webhook(webhooks_data, enabled_events)
      webhook_url = SpreeStripe::Gateway::WEBHOOK_URL

      webhooks_data.find do |webhook|
        webhook[:url] == webhook_url && webhook[:enabled_events].sort == enabled_events.sort
      end
    end

    def ensure_webhook(payment_method, stripe_webhook, connect, events)
      if stripe_webhook.nil?
        create_webhook_endpoint(payment_method, connect, events)
      else
        webhook_key = WebhookKey.find_by(stripe_id: stripe_webhook[:id])

        if webhook_key.present?
          webhook_key.payment_methods << payment_method if webhook_key.payment_methods.exclude?(payment_method)
        else
          create_webhook_endpoint(payment_method, connect, events)
        end
      end
    end

    def create_webhook_endpoint(payment_method, connect, events)
      params = build_webhook_params(connect, events)
      stripe_webhook = Stripe::WebhookEndpoint.create(params, { api_key: payment_method.preferred_secret_key })

      SpreeStripe::WebhookKey.create!(
        stripe_id: stripe_webhook[:id],
        signing_secret: stripe_webhook[:secret],
        kind: connect ? :connect : :direct,
        payment_methods: [payment_method]
      )

      Rails.cache.delete('stripe_webhook_signing_keys')
    end

    def build_webhook_params(connect, events)
      {
        url: SpreeStripe::Gateway::WEBHOOK_URL,
        enabled_events: events,
        connect: connect
      }
    end
  end
end
