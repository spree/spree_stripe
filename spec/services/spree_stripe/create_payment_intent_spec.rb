require 'spec_helper'

RSpec.describe SpreeStripe::CreatePaymentIntent, vcr: true do
  subject(:payment_intent) { described_class.new.call(order, gateway, stripe_payment_method_id: stripe_payment_method_id, off_session: off_session) }

  let(:store) { Spree::Store.default }
  let(:stripe_payment_method_id) { 'pm_card_visa' }
  let(:off_session) { false }
  let!(:gateway) { create(:stripe_gateway, stores: [store]) }
  let(:order) { create(:order, total: 10.00, store: store, state: :payment) }

  context 'when order is not valid' do
    let(:order) { create(:order, total: 10.00, store: store, state: :delivery, bill_address: nil, ship_address: nil) }

    # regression for https://sentry.io/organizations/vendo-commerce/issues/3807541570/?project=6055160
    it 'still creates a payment intent' do
      order.ship_address = Spree::Address.new(country: store.default_country)
      expect(order.valid?).to be false
      expect(payment_intent).to be_present
    end
  end

  it 'saves payment intent in the database' do
    expect(payment_intent).to be_persisted

    expect(payment_intent.stripe_payment_method_id).to eq(stripe_payment_method_id)
    expect(payment_intent.amount).to eq(order.total)
    expect(payment_intent.client_secret).to be_present
    expect(payment_intent.customer_id).to be_present
    expect(payment_intent.ephemeral_key_secret).to be_present
    expect(payment_intent.order).to eq(order)
    expect(payment_intent.payment_method).to eq(gateway)
  end
end
