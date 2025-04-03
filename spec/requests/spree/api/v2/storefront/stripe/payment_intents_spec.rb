require 'spec_helper'

RSpec.describe Spree::Api::V2::Storefront::Stripe::PaymentIntentsController, type: :request do
  let(:store) { Spree::Store.default }

  let!(:gateway) { create(:stripe_gateway, stores: [store]) }
  let!(:order) { create(:order_with_line_items, user: user) }
  let(:user) { nil }

  let(:headers) { { 'X-Spree-Order-Token' => order.token } }
  let(:params) do
    {
      payment_intent: {
        amount: amount,
        stripe_payment_method_id: stripe_payment_method_id,
        off_session: off_session
      }
    }
  end

  let(:amount) { 12.34 }
  let(:stripe_payment_method_id) { 'pm_1234567890' }
  let(:off_session) { false }
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

      allow_any_instance_of(gateway.class).to receive(:create_payment_intent)
        .with(Spree::Money.new(amount).cents, order, payment_method_id: stripe_payment_method_id, off_session: off_session)
        .and_return(stripe_response)

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
      expect(payment_intent.stripe_payment_method_id).to eq(stripe_payment_method_id)
    end
  end

  describe 'payment_intents#update' do
    let(:payment_intent) { create(:payment_intent, stripe_id: payment_intent_id, order: order, payment_method: gateway) }

    before do
      allow_any_instance_of(gateway.class).to receive(:update_payment_intent)
        .with(payment_intent.stripe_id, Spree::Money.new(amount).cents, order, stripe_payment_method_id)
        .and_return(stripe_response)

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

  describe 'payment_intents#confirm' do
    subject do
      post "/api/v2/storefront/stripe/payment_intents/#{payment_intent.id}/confirm", headers: headers
    end

    let(:payment_intent) do
      order.payment_intents.create!(
        amount: order.total,
        payment_method: gateway,
        stripe_id: payment_intent_id,
        client_secret: client_secret
      )
    end
    let!(:gateway_customer) { create(:gateway_customer, profile_id: 'cus_1234567890', user: user, payment_method: gateway) }
    let(:user) { create(:user) }
    let(:client_secret) { 'pi_123_secret_456' }
    let(:stripe_payment_intent) do
      Stripe::StripeObject.construct_from(
        id: payment_intent_id,
        status: 'requires_payment_method',
        amount: (order.total * 100).to_i,
        currency: 'usd',
        client_secret: client_secret
      )
    end

    before do
      order.update_columns(state: 'payment', total: 10.0)
      allow(Stripe::PaymentIntent).to receive(:retrieve).and_return(stripe_payment_intent)
    end

    context 'when order is canceled' do
      before do
        payment_intent.update(order: create(:order))
        subject
      end

      it 'returns 404' do
        expect(response.status).to eq(404)
      end
    end

    context 'when order is already completed' do
      before do
        order.update_columns(state: 'complete', completed_at: Time.current)
        subject
      end

      it 'returns 422' do
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq(Spree.t('order_already_completed'))
      end
    end

    context "when payment intent's order is not the current order" do
      before do
        payment_intent.update(order: create(:order))
        subject
      end

      it 'returns 404' do
        expect(response.status).to eq(404)
      end
    end

    context 'when payment intent status is succeeded' do
      let(:stripe_payment_intent) do
        Stripe::StripeObject.construct_from(
          id: payment_intent_id,
          status: 'succeeded',
          amount: (order.total * 100).to_i,
          currency: 'usd',
          customer: user.gateway_customers.last.profile_id,
          latest_charge: 'ch_3QXRgr2ESifGlJez02SSg61f',
          client_secret: client_secret
        )
      end

      let(:stripe_charge) do
        # TODO: Create factory for this
        Stripe::StripeObject.construct_from(
          id: 'ch_3QXRgr2ESifGlJez02SSg61f',
          billing_details: {
            name: 'John Doe',
            email: 'john.doe@example.com',
            phone: '+1234567890',
            address: {
              city: 'New York',
              country: 'US'
            }
          },
          payment_method_details: {
            card: Stripe::StripeObject.construct_from(
              brand: 'mastercard',
              checks: Stripe::StripeObject.construct_from(
                address_line1_check: 'unchecked',
                address_postal_code_check: 'unchecked',
                cvc_check: nil
              ),
              country: 'PL',
              exp_month: 11,
              exp_year: 2025,
              fingerprint: 'FZqjhq46SWprIY8i',
              funding: 'debit',
              installments: nil,
              last4: '3522',
              mandate: nil,
              network: 'mastercard',
              three_d_secure: nil,
              wallet: Stripe::StripeObject.construct_from(
                apple_pay: nil,
                dynamic_last4: '3139',
                type: 'apple_pay'
              )
            ),
            type: 'card'
          },
          payment_method: 'pm_1234567890'
        )
      end

      before do
        allow(Stripe::Charge).to receive(:retrieve).and_return(stripe_charge)
        subject
      end

      it 'completes the order' do
        expect(response.status).to eq(200)
        expect(json_response['data']['type']).to eq('payment_intent')

        expect(order.reload.completed?).to be(true)
      end
    end

    context 'when payment intent has other status' do
      before do
        subject
      end

      it 'returns error message' do
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq(Spree.t("stripe.payment_intent_errors.#{stripe_payment_intent.status}"))
      end
    end

    context 'when gateway error occurs' do
      let(:stripe_payment_intent) do
        Stripe::StripeObject.construct_from(
          id: payment_intent_id,
          status: 'succeeded',
          amount: (order.total * 100).to_i,
          currency: 'usd',
          charge: 'ch_3QXRgr2ESifGlJez02SSg61f',
          client_secret: client_secret
        )
      end

      before do
        allow_any_instance_of(SpreeStripe::CompleteOrder).to receive(:call)
          .and_raise(Spree::Core::GatewayError, 'Payment failed')
        subject
      end

      it 'returns error message' do
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq('Payment failed')
      end
    end
  end
end
