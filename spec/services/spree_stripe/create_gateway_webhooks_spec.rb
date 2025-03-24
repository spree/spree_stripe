require 'spec_helper'

RSpec.describe SpreeStripe::CreateGatewayWebhooks do
  let(:create_gateway_webhooks) { described_class.new }

  describe '#call' do
    subject { create_gateway_webhooks.call(payment_method: payment_method) }

    let(:payment_method) { create(:stripe_gateway) }
    let(:webhook_key) { SpreeStripe::WebhookKey.last }

    let(:stripe_webhooks) { Stripe::WebhookEndpoint.list({}, { api_key: payment_method.preferred_secret_key }) }
    let(:stripe_webhook) { stripe_webhooks[:data].find { |webhook| webhook[:url] == 'https://spreecommerce.org/stripe' } }

    before do
      Rails.application.routes.default_url_options[:host] = 'spreecommerce.org'
    end

    it 'creates a webhook endpoint', vcr: { cassette_name: 'create_gateway_webhooks' } do
      expect { subject }.to change(SpreeStripe::WebhookKey, :count).by(1)

      expect(stripe_webhook.enabled_events).to eq(SpreeStripe::Config[:supported_webhook_events])
      expect(stripe_webhook.status).to eq('enabled')

      expect(webhook_key.stripe_id).to eq(stripe_webhook.id)
      expect(webhook_key.signing_secret).to be_present
      expect(webhook_key.payment_methods).to contain_exactly(*payment_method)
    end

    context 'when the webhook endpoint already exists' do
      context 'when the webhook key exists', vcr: { cassette_name: 'existing_gateway_webhooks' } do
        let!(:webhook_key) { create(:stripe_webhook_key, stripe_id: stripe_webhook.id, payment_methods: [other_payment_method]) }
        let(:other_payment_method) { create(:stripe_gateway) }

        it 'adds the payment method to the webhook key' do
          expect { subject }.not_to change(SpreeStripe::WebhookKey, :count)

          expect(webhook_key.reload.payment_methods).to contain_exactly(*payment_method, other_payment_method)
        end
      end

      context 'when the webhook key does not exist' do
        let(:spree_webhook_endpoints) { stripe_webhooks[:data].find_all { |webhook| webhook[:url] == 'https://spreecommerce.org/stripe' } }

        it 'creates a new webhook key', vcr: { cassette_name: 'create_another_gateway_webhooks' } do
          expect { subject }.to change(SpreeStripe::WebhookKey, :count).by(1)

          expect(spree_webhook_endpoints.count).to eq(2)
          expect(webhook_key.payment_methods).to contain_exactly(*payment_method)
        end
      end
    end
  end
end
