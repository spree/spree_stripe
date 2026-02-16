require 'spec_helper'

RSpec.describe SpreeStripe::Gateway::PaymentSessions do
  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:gateway) { create(:stripe_gateway, stores: [store]) }

  let(:customer) { instance_double(Spree::GatewayCustomer, profile_id: 'cus_test_123') }
  let(:pi_response) do
    ActiveMerchant::Billing::Response.new(
      true, nil,
      { 'client_secret' => 'pi_secret_abc' },
      authorization: 'pi_new_intent_123'
    )
  end
  let(:ephemeral_key_response) do
    ActiveMerchant::Billing::Response.new(
      true, nil,
      { 'secret' => 'ek_test_secret' },
      authorization: 'ek_test_secret'
    )
  end

  before do
    allow(gateway).to receive(:fetch_or_create_customer).and_return(customer)
    allow(gateway).to receive(:create_payment_intent).and_return(pi_response)
    allow(gateway).to receive(:create_ephemeral_key).and_return(ephemeral_key_response)
  end

  describe '#session_required?' do
    it 'returns true by default' do
      expect(gateway.session_required?).to be true
    end

    it 'returns false when use_legacy_payment_intents is true' do
      allow(SpreeStripe::Config).to receive(:[]).with(:use_legacy_payment_intents).and_return(true)
      expect(gateway.session_required?).to be false
    end
  end

  describe '#payment_session_class' do
    it 'returns Spree::PaymentSessions::Stripe' do
      expect(gateway.payment_session_class).to eq(Spree::PaymentSessions::Stripe)
    end
  end

  describe '#create_payment_session' do
    subject { gateway.create_payment_session(order: order) }

    it 'creates a Stripe PaymentIntent' do
      expect(gateway).to receive(:create_payment_intent).with(
        order.display_total.cents, order,
        payment_method_id: nil,
        customer_profile_id: 'cus_test_123'
      ).and_return(pi_response)
      subject
    end

    it 'creates an ephemeral key' do
      expect(gateway).to receive(:create_ephemeral_key).with('cus_test_123')
      subject
    end

    it 'persists a PaymentSessions::Stripe record' do
      session = subject
      expect(session).to be_a(Spree::PaymentSessions::Stripe)
      expect(session).to be_persisted
      expect(session.external_id).to eq('pi_new_intent_123')
      expect(session.status).to eq('pending')
      expect(session.order).to eq(order)
      expect(session.payment_method).to eq(gateway)
    end

    it 'stores client_secret and ephemeral_key_secret in external_data' do
      session = subject
      expect(session.external_data['client_secret']).to eq('pi_secret_abc')
      expect(session.external_data['ephemeral_key_secret']).to eq('ek_test_secret')
    end

    it 'stores customer_external_id' do
      session = subject
      expect(session.customer_external_id).to eq('cus_test_123')
    end

    it 'returns nil when amount is zero' do
      allow(order).to receive(:total_minus_store_credits).and_return(0)
      expect(subject).to be_nil
    end

    context 'with a custom amount' do
      subject { gateway.create_payment_session(order: order, amount: 50.0) }

      it 'uses the provided amount' do
        expect(gateway).to receive(:create_payment_intent).with(
          5000, order,
          payment_method_id: nil,
          customer_profile_id: 'cus_test_123'
        ).and_return(pi_response)
        session = subject
        expect(session.amount).to eq(50.0)
      end
    end

    context 'with external_data containing stripe_payment_method_id' do
      subject { gateway.create_payment_session(order: order, external_data: { stripe_payment_method_id: 'pm_card_visa' }) }

      it 'passes payment_method_id to create_payment_intent' do
        expect(gateway).to receive(:create_payment_intent).with(
          anything, order,
          payment_method_id: 'pm_card_visa',
          customer_profile_id: 'cus_test_123'
        ).and_return(pi_response)
        subject
      end

      it 'stores stripe_payment_method_id in external_data' do
        session = subject
        expect(session.external_data['stripe_payment_method_id']).to eq('pm_card_visa')
      end
    end

    context 'without a customer' do
      before do
        allow(gateway).to receive(:fetch_or_create_customer).and_return(nil)
      end

      it 'does not create an ephemeral key' do
        expect(gateway).not_to receive(:create_ephemeral_key)
        subject
      end

      it 'creates the session without customer data' do
        session = subject
        expect(session.customer_external_id).to be_nil
      end
    end
  end

  describe '#update_payment_session' do
    let(:payment_session) do
      create(:stripe_payment_session,
             order: order,
             payment_method: gateway,
             amount: 20.0,
             external_id: 'pi_existing_123',
             external_data: { 'client_secret' => 'pi_secret_old' })
    end

    before do
      allow(gateway).to receive(:update_payment_intent)
    end

    it 'calls update_payment_intent on Stripe' do
      expect(gateway).to receive(:update_payment_intent).with(
        'pi_existing_123', 3000, order, nil
      )
      gateway.update_payment_session(payment_session: payment_session, amount: 30.0)
    end

    it 'updates the session amount' do
      gateway.update_payment_session(payment_session: payment_session, amount: 30.0)
      expect(payment_session.reload.amount).to eq(30.0)
    end

    it 'merges new external_data' do
      gateway.update_payment_session(
        payment_session: payment_session,
        external_data: { stripe_payment_method_id: 'pm_new' }
      )
      expect(payment_session.reload.external_data['stripe_payment_method_id']).to eq('pm_new')
      expect(payment_session.external_data['client_secret']).to eq('pi_secret_old')
    end
  end

  describe '#complete_payment_session' do
    let(:payment_session) do
      create(:stripe_payment_session,
             order: order,
             payment_method: gateway,
             external_id: 'pi_complete_123')
    end

    context 'when the payment intent is accepted' do
      let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_complete_123', status: 'succeeded', payment_method: { type: 'card' }) }

      before do
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
        allow(SpreeStripe::CompleteOrder).to receive_message_chain(:new, :call).and_return(order)
      end

      it 'processes and completes the session' do
        gateway.complete_payment_session(payment_session: payment_session)
        payment_session.reload
        expect(payment_session.status).to eq('completed')
      end

      it 'calls CompleteOrder with the payment session' do
        expect(SpreeStripe::CompleteOrder).to receive(:new).with(payment_intent: payment_session).and_return(double(call: order))
        gateway.complete_payment_session(payment_session: payment_session)
      end
    end

    context 'when the payment intent is not accepted' do
      let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_complete_123', status: 'requires_payment_method', payment_method: { type: 'card' }) }

      before do
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
      end

      it 'fails the session' do
        gateway.complete_payment_session(payment_session: payment_session)
        expect(payment_session.reload.status).to eq('failed')
      end

      it 'does not call CompleteOrder' do
        expect(SpreeStripe::CompleteOrder).not_to receive(:new)
        gateway.complete_payment_session(payment_session: payment_session)
      end
    end

    context 'when the session is already completed' do
      let(:stripe_pi) { Stripe::StripeObject.construct_from(id: 'pi_complete_123', status: 'requires_payment_method', payment_method: { type: 'card' }) }

      before do
        payment_session.update_column(:status, 'completed')
        allow(gateway).to receive(:retrieve_payment_intent).and_return(stripe_pi)
      end

      it 'does not fail a completed session' do
        gateway.complete_payment_session(payment_session: payment_session)
        expect(payment_session.reload.status).to eq('completed')
      end
    end
  end
end
