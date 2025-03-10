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
      let!(:stripe_customer) { create(:stripe_customer, user: user, payment_method: stripe_gateway, profile_id: 'gcus_1QVdlA2ESifGlJezwNCqGKOP') } # to avoid API call
      let(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: 'pi_3Qd7ay2ESifGlJez0iSw49k1') }

      it_behaves_like 'a successful payment'
    end

    context 'quick checkout', vcr: { cassette_name: 'successful_payment_intent_with_charge' } do
      let!(:order) { create(:order_with_line_items, store: store, user: user, state: :address) }
      let!(:stripe_customer) { create(:stripe_customer, user: user, payment_method: stripe_gateway, profile_id: 'gcus_1QVdlA2ESifGlJezwNCqGKOP') } # to avoid API call
      let(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, stripe_id: 'pi_3Qd7ay2ESifGlJez0iSw49k1', amount: 19.99) }

      it 'completes the order' do
        expect { subject }.to change { order.reload.state }.to('complete')
        expect(order.completed_at).to be_present
      end
    end
  end
end
