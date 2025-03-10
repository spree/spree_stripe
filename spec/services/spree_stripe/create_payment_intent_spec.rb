require 'spec_helper'

RSpec.describe SpreeStripe::CreatePaymentIntent, vcr: true do
  let(:store) { Spree::Store.default }
  let!(:gateway) { create(:stripe_gateway, stores: [store]) }

  subject { described_class.new.call(order, gateway) }

  context 'when order is not valid' do
    let(:order) { create(:order, total: 10.00, store: store, state: :delivery, bill_address: nil, ship_address: nil) }

    # regression for https://sentry.io/organizations/vendo-commerce/issues/3807541570/?project=6055160
    it 'still creates a payment intent' do
      order.ship_address = Spree::Address.new(country: store.default_country)
      expect(order.valid?).to be false
      expect(subject).to be_present
    end
  end
end
