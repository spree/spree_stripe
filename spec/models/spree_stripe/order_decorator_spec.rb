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

  describe '#associate_user!' do
    let(:order) { create(:order_with_line_items, store: store, user: nil, shipping_address: shipping_address) }
    let(:new_user) { create(:user, email: 'jane.zoe@example.com') }

    let(:shipping_address) do
      create(
        :address,
        firstname: 'Jane',
        lastname: 'Zoe',
        address1: '100 California Street',
        address2: nil,
        city: 'San Francisco',
        zipcode: '94111',
        state: california_state,
        country: usa_country
      )
    end

    let(:usa_country) { Spree::Country.find_by(iso: 'US') || create(:usa_country) }
    let(:california_state) { create(:state, name: 'California', abbr: 'CA', country: usa_country) }

    let!(:gateway_customer) { create(:gateway_customer, user: new_user, payment_method: stripe_gateway, profile_id: 'cus_RQdclxFVLH4oau') }
    let!(:payment_intent) { create(:payment_intent, order: order, payment_method: stripe_gateway, amount: 4000, stripe_id: 'pi_3QY2qD2ESifGlJez0VuzXjwK') }

    it 'updates the payment intent with customer information' do
      VCR.use_cassette('update_payment_intent_new_address') do
        expect { order.associate_user!(new_user) }.to change { payment_intent.reload.customer_id }.from(nil).to('cus_RQdclxFVLH4oau')
      end
    end

    context 'when there are no payment intents' do
      let!(:payment_intent) { nil }

      it 'skips updating the payment intent' do
        expect_any_instance_of(SpreeStripe::PaymentIntent).not_to receive(:update_stripe_payment_intent)
        order.associate_user!(new_user)
      end
    end
  end
end
