require 'spec_helper'

RSpec.describe SpreeStripe::CompleteOrder, :vcr do
  describe '#call' do
    subject { described_class.new(payment_intent: payment_intent).call }

    let(:store) { Spree::Store.default }
    let!(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let(:user) { create(:user) }

    shared_examples 'a successful payment' do
      it 'completes the order' do
        expect { subject }.to change { order.reload.state }.to('complete')
        expect(order.completed_at).to be_present
      end

      it 'returns the updated order' do
        expect(subject).to be_a(Spree::Order)
        expect(subject.id).to eq(order.id)
      end

      it 'creates a new payment record' do
        expect { subject }.to change { order.payments.count }.by(1)
        expect(order.payments.last.state).to eq 'completed'
        expect(order.payments.last.response_code).to eq payment_intent.stripe_id
      end
    end

    context 'regular checkout', vcr: { cassette_name: 'successful_payment_intent_with_charge' } do
      let!(:order) { create(:order_with_line_items, store: store, user: user, state: :payment) }
      let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: customer_id) } # to avoid API call
      let(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: payment_intent_id) }

      let(:customer_id) { 'cus_T5CK5Lf4jU4kCw' }
      let(:payment_intent_id) { 'pi_3SaJc7FmGsiQWfE60qR1EA2E' }

      it_behaves_like 'a successful payment'
    end

    context 'quick checkout', vcr: { cassette_name: 'successful_payment_intent_with_charge' } do
      let!(:order) { create(:order_with_line_items, store: store, user: user, state: :address, line_items_price: 19.99) }
      let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: customer_id) } # to avoid API call
      let(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: payment_intent_id, amount: 19.99) }
      let!(:shipping_method) do
        create(:shipping_method, name: 'Shipping Method', code: 'shipping_method', calculator: create(:shipping_calculator, preferred_amount: 0))
      end

      let(:customer_id) { 'cus_T5CK5Lf4jU4kCw' }
      let(:payment_intent_id) { 'pi_3SaJc7FmGsiQWfE60qR1EA2E' }

      it 'completes the order' do
        expect { subject }.to change { order.reload.state }.to('complete')
        expect(order.completed_at).to be_present
      end

      it 'attaches the customer to the credit card' do
        subject
        expect(user.reload.default_credit_card.gateway_customer_profile_id).to eq(customer_id)
        expect(user.reload.default_credit_card.gateway_customer_id).to eq(stripe_customer.id)
      end
    end

    context 'for an order with a sepa debit payment intent in processing state', vcr: { cassette_name: 'processing_sepa_debit_payment_intent' } do
      let!(:order) { create(:order_with_line_items, store: store, user: user, state: :payment) }
      let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: customer_id) } # to avoid API call
      let(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: payment_intent_id) }

      let(:customer_id) { 'cus_T5CK5Lf4jU4kCw' }
      let(:payment_intent_id) { 'pi_3Sc2EfFmGsiQWfE60SFX1KGY' }

      it 'completes the order' do
        expect { subject }.to change { order.reload.state }.to('complete')

        expect(order.completed_at).to be_present
        expect(order.payment_state).to eq('balance_due')
      end

      it 'creates a new payment record' do
        expect { subject }.to change { order.payments.count }.by(1)

        expect(order.payments.last.state).to eq('pending')
        expect(order.payments.last.response_code).to eq(payment_intent.stripe_id)
      end
    end

    context 'for an order with a bank transfer payment intent in requires_action state', vcr: { cassette_name: 'retrieve_payment_intent_bank_transfer' } do
      let!(:order) { create(:order_with_line_items, store: store, user: user, state: :payment) }
      let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: customer_id) } # to avoid API call
      let(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: payment_intent_id) }

      let(:customer_id) { 'cus_TZFk4Fxe9gABNI' }
      let(:payment_intent_id) { 'pi_3ScPMjFmGsiQWfE61qMaWSFF' }
      let(:payment_method_id) { 'pm_1ScPNbFmGsiQWfE6IQ5cXwYc' }

      it 'completes the order' do
        expect { subject }.to change { order.reload.state }.to('complete')

        expect(order.completed_at).to be_present
        expect(order.payment_state).to eq('balance_due')
      end

      it 'creates a new payment record' do
        expect { subject }.to change { order.payments.count }.by(1)

        expect(order.payments.last.state).to eq('pending')
        expect(order.payments.last.response_code).to eq(payment_intent.stripe_id)

        expect(order.payments.last.source).to be_a SpreeStripe::PaymentSources::BankTransfer
        expect(order.payments.last.source.gateway_payment_profile_id).to eq(payment_method_id)
      end
    end
  end
end
