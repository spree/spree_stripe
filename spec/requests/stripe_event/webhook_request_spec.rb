require 'spec_helper'

RSpec.describe 'Stripe webhook requests', type: :request do
  let(:store) { Spree::Store.default }

  before { host!(store.url) }

  describe 'POST /stripe' do
    subject(:receive_event) { post '/stripe', params: event.to_json, headers: headers }

    let(:event) { JSON.parse(File.read('spec/fixtures/files/payment_intent_succeeded.json')) }
    let(:signature) { Stripe::Webhook::Signature.compute_signature(timestamp, event.to_json, signature_secret) }
    let(:timestamp) { Time.now }
    let(:signature_secret) { 'whsec_1234567890' }
    let(:headers) { { 'Stripe-Signature' => "t=#{timestamp.to_i},v1=#{signature}", 'Content-Type' => 'application/json' } }

    context 'with a signing secret in the environment' do
      let(:signing_secret) { 'whsec_1234567890' }

      before do
        allow(ENV).to receive(:[]).with(anything).and_call_original
        allow(ENV).to receive(:[]).with('STRIPE_SIGNING_SECRET').and_return(signing_secret)
      end

      it 'responds with a 200' do
        receive_event
        expect(response).to have_http_status(:ok)
      end

      context 'when the signing secret is invalid' do
        let(:signature_secret) { 'whsec_1234567891' }

        it 'responds with a 400' do
          receive_event
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'with a webhook key' do
      let(:signing_secret) { 'whsec_1234567890' }

      before do
        create(:stripe_webhook_key, signing_secret: signing_secret)
      end

      it 'responds with a 200' do
        receive_event
        expect(response).to have_http_status(:ok)
      end

      context 'when the signing secret is invalid' do
        let(:signature_secret) { 'whsec_1234567891' }

        it 'responds with a 400' do
          receive_event
          expect(response).to have_http_status(:bad_request)
        end
      end
    end

    context 'without any signing secrets' do
      it 'responds with a 400' do
        receive_event
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'when receiving the payment intent succeeded event' do
      let!(:payment_intent) { create(:payment_intent, stripe_id: payment_intent_id) }
      let(:payment_intent_id) { 'pi_00000000000000' }

      before do
        create(:stripe_webhook_key, signing_secret: 'whsec_1234567890')
      end

      it 'processes the payment intent succeeded event' do
        expect { receive_event }.to have_enqueued_job(SpreeStripe::CompleteOrderJob).with(payment_intent.id)
      end
    end
  end
end
