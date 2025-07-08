module SpreeStripe
  class CreateGatewayWebhooks
    def call(payment_method:, events: SpreeStripe::Config[:supported_webhook_events], connect: false)
      webhook_list = Stripe::WebhookEndpoint.list({}, { api_key: payment_method.preferred_secret_key })
      webhook = find_webhook(payment_method, webhook_list[:data], events)

      ensure_webhook(payment_method, webhook, connect, events)
    end

    private

    def find_webhook(payment_method, webhooks_data, enabled_events)
      webhook_url = payment_method.webhook_url

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
      params = build_webhook_params(payment_method, connect, events)
      stripe_webhook = Stripe::WebhookEndpoint.create(params, { api_key: payment_method.preferred_secret_key })

      SpreeStripe::WebhookKey.create!(
        stripe_id: stripe_webhook[:id],
        signing_secret: stripe_webhook[:secret],
        payment_methods: [payment_method]
      )

      Rails.cache.delete('stripe_webhook_signing_keys')
    end

    def build_webhook_params(payment_method, connect, events)
      {
        url: payment_method.webhook_url,
        enabled_events: events,
        connect: connect
      }
    end
  end
end
