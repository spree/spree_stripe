require 'spec_helper'

RSpec.describe SpreeStripe::OrderDecorator do
  let(:store) { Spree::Store.default }
  let(:user) { create(:user) }
  let(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:stripe_gateway) { create(:stripe_gateway, stores: [store]) }
  let!(:stripe_customer) { create(:gateway_customer, user: user, payment_method: stripe_gateway, profile_id: 'cus_123') }
  let!(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, amount: order.total_minus_store_credits) }

  before { order.reload }

  it 'returns payment intents' do
    expect(order.payment_intents).to eq([payment_intent])
  end

  it "updates the payment intent when the order is updated" do
    # order updater runs twice during recalculate
    expect(Stripe::PaymentIntent).to receive(:update).twice.and_return(double(id: payment_intent.stripe_id))
    expect { Spree::Cart::SetQuantity.call(order: order, line_item: order.line_items.first, quantity: 2) }.to change { payment_intent.reload.amount }
  end

  context 'when the order is completed' do
    let(:order) { create(:order_with_line_items, store: store, user: user, state: :complete, completed_at: Time.current) }

    it "doesn't update the payment intent" do
      expect { Spree::Cart::SetQuantity.call(order: order, line_item: order.line_items.first, quantity: 2) }.not_to change { payment_intent.reload.amount }
    end
  end
end
