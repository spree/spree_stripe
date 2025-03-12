require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::Stripe::PaymentIntentsController, type: :request do
  let(:store) { Spree::Store.default }

  let!(:gateway) { create(:stripe_gateway, stores: [store]) }
  let!(:order) { create(:order_with_line_items, user: nil) }

  let(:headers) { { 'X-Spree-Order-Token' => order.token } }
    let(:params) do
      {
        payment_intent: {
          amount: amount,
          stripe_payment_method_id: stripe_payment_method_id
        }
      }
    end

  let(:amount) { 12.34 }
  let(:stripe_payment_method_id) { 'pm_1234567890' }

  let(:stripe_response) do
    double(
      :stripe_response,
      authorization: payment_intent_id,
      params: { 'client_secret' => client_secret }
    )
  end

  let(:payment_intent_id) { 'pi_1234567890' }
  let(:client_secret) { 'pi_1234567890_secret_1234567890' }

  describe 'payment_intents#create' do
    let(:payment_intent) { order.reload.payment_intents.last }

    before do
      order.update(total: amount)

      allow_any_instance_of(gateway.class).to receive(:create_payment_intent).
        with(Spree::Money.new(amount).cents, order, payment_method_id: stripe_payment_method_id, off_session: false).
        and_return(stripe_response)

      post '/api/v2/storefront/stripe/payment_intents', headers: headers, params: params
    end

    include_context 'returns 200 HTTP status'

    it 'responds with the payment intent data' do
      expect(json_response['data']['id']).to eq(payment_intent.id.to_s)
      expect(json_response['data']['type']).to eq('payment_intent')

      expect(json_response['data']).to have_attribute(:stripe_id).with_value(payment_intent_id)
      expect(json_response['data']).to have_attribute(:client_secret).with_value(client_secret)
      expect(json_response['data']).to have_attribute(:amount).with_value(amount.to_s)
    end

    it 'creates a payment intent' do
      expect(payment_intent).to be_present
      expect(payment_intent.amount).to eq(amount)
      expect(payment_intent.payment_method).to eq(gateway)
      expect(payment_intent.stripe_id).to eq(payment_intent_id)
      expect(payment_intent.client_secret).to eq(client_secret)
    end
  end

  describe 'payment_intents#update' do
    let(:payment_intent) { create(:payment_intent, stripe_id: payment_intent_id, order: order, payment_method: gateway) }

    before do
      allow_any_instance_of(gateway.class).to receive(:update_payment_intent).
        with(payment_intent.stripe_id, Spree::Money.new(amount).cents, order, stripe_payment_method_id).
        and_return(stripe_response)

      patch "/api/v2/storefront/stripe/payment_intents/#{payment_intent.id}", headers: headers, params: params
    end

    include_context 'returns 200 HTTP status'

    it 'responds with the payment intent data' do
      expect(json_response['data']['id']).to eq(payment_intent.id.to_s)
      expect(json_response['data']['type']).to eq('payment_intent')

      expect(json_response['data']).to have_attribute(:stripe_id).with_value(payment_intent_id)
      expect(json_response['data']).to have_attribute(:amount).with_value(amount.to_s)
    end

    it 'updates the payment intent' do
      expect(payment_intent.reload.amount).to eq(amount)
      expect(payment_intent.payment_method).to eq(gateway)
      expect(payment_intent.stripe_id).to eq(payment_intent_id)
      expect(payment_intent.stripe_payment_method_id).to eq(stripe_payment_method_id)
    end
  end
end
