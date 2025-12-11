require 'spec_helper'

RSpec.describe SpreeStripe::WebhookHandlers::PaymentIntentPaymentFailed do
  describe '#call' do
    subject { described_class.new.call(event) }

    let(:store) { Spree::Store.default }
    let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
    let(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway) }
    let!(:order) { create(:completed_order_with_totals, store: store) }

    let(:event) do
      double(
        data: double(
          object: double(
            id: payment_intent.stripe_id,
            object: 'payment_intent'
          )
        )
      )
    end

    it 'cancels the order' do
      expect { subject }.to change { order.reload.state }.from('complete').to('canceled')

      expect(order.reload.payment_state).to eq('void')
      expect(order.completed_at).to be_present
    end
  end
end
